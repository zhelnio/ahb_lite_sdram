/* Simple SDRAM controller for MIPSfpga+ system AHB-Lite bus
 * Copyright(c) 2016 Stanislav Zhelnio
 * https://github.com/zhelnio/ahb_lite_sdram
 */

module ahb_lite_sdram_old
#(
    parameter   ADDR_BITS           = 13,       /* SDRAM Address input size */
                ROW_BITS            = 13,       /* SDRAM Row address size */
                COL_BITS            = 10,       /* SDRAM Column address size */
                DQ_BITS             = 16,       /* SDRAM Data i/o size, only x16 supported */
                DM_BITS             = 2,        /* SDRAM Data i/o mask size, only x2 supported */
                BA_BITS             = 2,        /* SDRAM Bank address size */
                SADDR_BITS          = (ROW_BITS + COL_BITS + BA_BITS),

    // delay params depends on Datasheet values, frequency and FSM states count
    // default values are calculated for simulation(!): Micron SDRAM Verilog model with fclk=50 MHz and CAS=2 
    parameter   DELAY_nCKE          = 20,       /* Init delay before bringing CKE high 
                                                   >= (T * fclk) where T    - CKE LOW init timeout 
                                                                       fclk - clock frequency  */
                DELAY_tREF          = 390,      /* Refresh period 
                                                   <= ((tREF - tRC) * fclk / RowsInBankCount)  */
                DELAY_tRP           = 0,        /* PRECHARGE command period 
                                                   >= (tRP * fclk - 1)                         */
                DELAY_tRFC          = 2,        /* AUTO_REFRESH period 
                                                   >= (tRFC * fclk - 2)                        */
                DELAY_tMRD          = 0,        /* LOAD_MODE_REGISTER to ACTIVE or REFRESH command 
                                                   >= (tMRD * fclk - 2)                        */
                DELAY_tRCD          = 0,        /* ACTIVE-to-READ or WRITE delay 
                                                   >= (tRCD * fclk - 1)                        */
                DELAY_tCAS          = 0,        /* CAS delay, also depends on clock phase shift 
                                                   =  (CAS - 1)                                */
                DELAY_afterREAD     = 0,        /* depends on tRC for READ with auto precharge command 
                                                   >= ((tRC - tRCD) * fclk - 1 - CAS)          */
                DELAY_afterWRITE    = 2,        /* depends on tRC for WRITE with auto precharge command 
                                                   >= ((tRC - tRCD) * fclk - 1)                */
                COUNT_initAutoRef   = 2         /* count of AUTO_REFRESH during Init operation */
)
(
    //ABB-Lite side
    input                               HCLK,    
    input                               HRESETn,
    input       [ 31 : 0 ]              HADDR,
    input       [  2 : 0 ]              HBURST,
    input                               HMASTLOCK,  // ignored
    input       [ 3:0]                  HPROT,      // ignored
    input                               HSEL,
    input       [  2 : 0 ]              HSIZE,
    input       [  1 : 0 ]              HTRANS,
    input       [ 31 : 0 ]              HWDATA,
    input                               HWRITE,
    input                               HREADY,
    output  reg [ 31 : 0 ]              HRDATA,
    output                              HREADYOUT,
    output                              HRESP,
    input                               SI_Endian,  // ignored

    //SDRAM side
    output                              CKE,
    output                              CSn,
    output                              RASn,
    output                              CASn,
    output                              WEn,
    output  reg [ ADDR_BITS - 1 : 0 ]   ADDR,
    output  reg [ BA_BITS   - 1 : 0 ]   BA,
    inout       [ DQ_BITS   - 1 : 0 ]   DQ,
    output  reg [ DM_BITS   - 1 : 0 ]   DQM
);

    //FSM states
    localparam  S_IDLE              = 6'd0,    /* Inited and waitong for AHB-Lite request */

                S_INIT0_nCKE        = 6'd1,    /* First step after HW reset */
                S_INIT1_nCKE        = 6'd2,    /* Holding CKE LOW for DELAY_nCKE before init steps */
                S_INIT2_CKE         = 6'd3,    /* Bringing CKE HIGH */
                S_INIT3_NOP         = 6'd4,    /* NOP after CKE is HIGH */
                S_INIT4_PRECHALL    = 6'd5,    /* Doing PRECHARGE */
                S_INIT5_NOP         = 6'd6,    /* Waiting for DELAY_tRP after PRECHARGE */
                S_INIT6_PREREF      = 6'd7,    /* Setting AUTO_REFRESH count*/
                S_INIT7_AUTOREF     = 6'd8,    /* Doing AUTO_REFRESH */
                S_INIT8_NOP         = 6'd9,    /* Waiting for DELAY_tRFC after AUTO_REFRESH */
                S_INIT9_LMR         = 6'd10,   /* Doing LOAD_MODE_REGISTER with CAS=2, BL=2, Seq  */
                S_INIT10_NOP        = 6'd11,   /* Waiting for DELAY_tMRD after LOAD_MODE_REGISTER */

                S_READ0_ACT         = 6'd20,   /* Doing ACTIVE */
                S_READ1_NOP         = 6'd21,   /* Waiting for DELAY_tRCD after ACTIVE */
                S_READ2_READ        = 6'd22,   /* Doing READ with Auto precharge */
                S_READ3_NOP         = 6'd23,   /* Waiting for DELAY_tCAS after READ */
                S_READ4_RD0         = 6'd24,   /* Reading 1st word */
                S_READ5_RD1         = 6'd25,   /* Reading 2nd word */
                S_READ6_NOP         = 6'd26,   /* Waiting for DELAY_afterREAD - it depends on tRC */

                S_WRITE0_ACT        = 6'd30,   /* Doing ACTIVE */
                S_WRITE1_NOP        = 6'd31,   /* Waiting for DELAY_tRCD after ACTIVE */
                S_WRITE2_WR0        = 6'd32,   /* Doing Write with Auto precharge, writing 1st word */
                S_WRITE3_WR1        = 6'd33,   /* Writing 2nd word */
                S_WRITE4_NOP        = 6'd34,   /* Waiting for DELAY_afterWRITE - it depends on tRC */

                S_AREF0_AUTOREF     = 6'd40,   /* Doing AUTO_REFRESH */
                S_AREF1_NOP         = 6'd41;   /* Waiting for DELAY_tRFC after AUTO_REFRESH */

    localparam  LD_SIZE = 25,       //long delay counter size
                SD_SIZE = 5,        //short delay counter size
                RP_SIZE = 4;        //operation repeat counter

    wire    [  5 : 0 ]              State;
    reg     [  5 : 0 ]              Next;
    wire    [ LD_SIZE - 1 : 0 ]     longDelay;
    reg     [ LD_SIZE - 1 : 0 ]     longDelayNext;
    wire    [ SD_SIZE - 1 : 0 ]     shortDelay;
    reg     [ SD_SIZE - 1 : 0 ]     shortDelayNext;
    wire    [ RP_SIZE - 1 : 0 ]     repeatCnt;
    reg     [ RP_SIZE - 1 : 0 ]     repeatCntNext;



    reg     [ DQ_BITS - 1 : 0    ]  DQreg;

    assign  DQ = DQreg;
    
    localparam  HTRANS_IDLE = 2'b0;
    localparam  HSIZE_X8    = 3'b000,
                HSIZE_X16   = 3'b001,
                HSIZE_X32   = 3'b010;

    assign  HRESP  = 1'b0;   
    assign  HREADYOUT = (State == S_IDLE);

    wire    NeedAction = HTRANS != HTRANS_IDLE && HSEL && HREADY;
    wire    NeedRefresh         = (longDelay  == 25'b0);
    wire    DelayFinished       = (shortDelay ==  5'b0);
    wire    BigDelayFinished    = (longDelay  == 25'b0);
    wire    RepeatsFinished     = (repeatCnt  ==  4'b0);

    mfp_register_r #(.WIDTH(6), .RESET(S_INIT0_nCKE)) State_r(HCLK, HRESETn, Next, 1'b1, State);
    mfp_register_r #(.WIDTH(25)) longDelay_r(HCLK, HRESETn, longDelayNext, 1'b1, longDelay);
    mfp_register_r #(.WIDTH(5)) shortDelay_r(HCLK, HRESETn, shortDelayNext, 1'b1, shortDelay);
    mfp_register_r #(.WIDTH(4)) repeatCnt_r(HCLK, HRESETn, repeatCntNext, 1'b1, repeatCnt);

    wire    [  2 : 0 ]              HSIZE_old;
    wire    [ 31 : 0 ]              HADDR_old;
    reg                             saveAddrPhase;
    mfp_register_r #(.WIDTH(3))  HSIZE_r(HCLK, HRESETn, HSIZE, saveAddrPhase, HSIZE_old);
    mfp_register_r #(.WIDTH(32)) HADDR_r(HCLK, HRESETn, HADDR, saveAddrPhase, HADDR_old);

    always @ (*) begin
        //State change decision
        Next = State;
        case(State)
            default             :   ;
            S_IDLE              :   Next = NeedAction ? (HWRITE ? S_WRITE0_ACT : S_READ0_ACT) 
                                                      : (NeedRefresh ? S_AREF0_AUTOREF : S_IDLE);  

            S_INIT0_nCKE        :   Next = S_INIT1_nCKE;
            S_INIT1_nCKE        :   Next = BigDelayFinished ? S_INIT2_CKE : S_INIT1_nCKE;
            S_INIT2_CKE         :   Next = S_INIT3_NOP;
            S_INIT3_NOP         :   Next = S_INIT4_PRECHALL;
            S_INIT4_PRECHALL    :   Next = (DELAY_tRP == 0) ? S_INIT6_PREREF : S_INIT5_NOP;
            S_INIT5_NOP         :   Next = DelayFinished ? S_INIT6_PREREF : S_INIT5_NOP;
            S_INIT6_PREREF      :   Next = S_INIT7_AUTOREF;
            S_INIT7_AUTOREF     :   Next = S_INIT8_NOP;
            S_INIT8_NOP         :   Next = ~DelayFinished  ? S_INIT8_NOP : (
                                           RepeatsFinished ? S_INIT9_LMR : S_INIT7_AUTOREF );
            S_INIT9_LMR         :   Next = S_INIT10_NOP;
            S_INIT10_NOP        :   Next = ~DelayFinished ? S_INIT10_NOP : (
                                           ~NeedAction    ? S_IDLE : (
                                           HWRITE         ? S_WRITE0_ACT : S_READ0_ACT));

            S_READ0_ACT         :   Next = (DELAY_tRCD == 0) ? S_READ2_READ : S_READ1_NOP;
            S_READ1_NOP         :   Next = DelayFinished ? S_READ2_READ : S_READ1_NOP;
            S_READ2_READ        :   Next = (DELAY_tCAS == 0) ? S_READ4_RD0 : S_READ3_NOP;
            S_READ3_NOP         :   Next = DelayFinished ? S_READ4_RD0 : S_READ3_NOP;
            S_READ4_RD0         :   Next = S_READ5_RD1;
            S_READ5_RD1         :   Next = (DELAY_afterREAD != 0) ? S_READ6_NOP : (
                                           NeedRefresh  ? S_AREF0_AUTOREF : S_IDLE );
            S_READ6_NOP         :   Next = ~DelayFinished ? S_READ6_NOP : (
                                           NeedRefresh  ? S_AREF0_AUTOREF : S_IDLE );

            S_WRITE0_ACT        :   Next = (DELAY_tRCD == 0) ? S_WRITE2_WR0 : S_WRITE1_NOP;
            S_WRITE1_NOP        :   Next = DelayFinished ? S_WRITE2_WR0 : S_WRITE1_NOP;
            S_WRITE2_WR0        :   Next = S_WRITE3_WR1;
            S_WRITE3_WR1        :   Next = (DELAY_afterWRITE != 0) ? S_WRITE4_NOP : (
                                            NeedRefresh  ? S_AREF0_AUTOREF : S_IDLE );
            S_WRITE4_NOP        :   Next = ~DelayFinished ? S_WRITE4_NOP : (
                                           NeedRefresh  ? S_AREF0_AUTOREF : S_IDLE );

            S_AREF0_AUTOREF     :   Next = S_AREF1_NOP;
            S_AREF1_NOP         :   Next = ~DelayFinished ? S_AREF1_NOP : S_IDLE;
        endcase

        //short delay counter
        case(State)
            S_INIT4_PRECHALL    :   shortDelayNext = DELAY_tRP - 1;
            S_INIT7_AUTOREF     :   shortDelayNext = DELAY_tRFC;
            S_INIT9_LMR         :   shortDelayNext = DELAY_tMRD;
            S_READ0_ACT         :   shortDelayNext = DELAY_tRCD - 1;
            S_READ2_READ        :   shortDelayNext = DELAY_tCAS - 1;
            S_READ5_RD1         :   shortDelayNext = DELAY_afterREAD - 1;
            S_WRITE0_ACT        :   shortDelayNext = DELAY_tRCD - 1;
            S_WRITE3_WR1        :   shortDelayNext = DELAY_afterWRITE - 1;
            S_AREF0_AUTOREF     :   shortDelayNext = DELAY_tRFC;
            default             :   shortDelayNext = DelayFinished ? 0 : shortDelay - 1;
        endcase

        //repeat operations counter
        case(State)
            S_INIT6_PREREF      :   repeatCntNext = COUNT_initAutoRef;
            S_INIT7_AUTOREF     :   repeatCntNext = RepeatsFinished ? 0 : repeatCnt - 1;
            default             :   repeatCntNext = repeatCnt;
        endcase

        //long delay counter
        case(State)
            S_INIT0_nCKE        :   longDelayNext = DELAY_nCKE;
            S_INIT7_AUTOREF     :   longDelayNext = DELAY_tREF;
            S_AREF0_AUTOREF     :   longDelayNext = DELAY_tREF;
            default             :   longDelayNext = BigDelayFinished ? 0 : longDelay - 1;
        endcase

        //addr phase save
        case(State)
            S_INIT10_NOP,
            S_IDLE              :   saveAddrPhase = HSEL;
            default             :   saveAddrPhase = 0;
        endcase
    end

    // address structure (example):
    // HADDR_old    (x32)   bbbb bbbb bbbb bbbb  bbbb bbbb bbbb bbbb
    // ByteNum      (x2 )   ---- ---- ---- ----  ---- ---- ---- --bb
    // AddrColumn   (x10)   ---- ---- ---- ----  ---- -bbb bbbb bb0-
    // AddrRow      (x13)   ---- ---- bbbb bbbb  bbbb b--- ---- ----
    // AddrBank     (x2 )   ---- --bb ---- ----  ---- ---- ---- ----
    //                    BA_BITS==^^ <====ROW_BITS===><=COL_BITS=>x

    wire    [              1 : 0 ]  ByteNum     =   HADDR_old [ 1 : 0 ];
    wire    [  COL_BITS  - 1 : 0 ]  AddrColumn  = { HADDR_old [ COL_BITS : 2 ] , 1'b0 };
    wire    [  ROW_BITS  - 1 : 0 ]  AddrRow     =   HADDR [ ROW_BITS + COL_BITS : COL_BITS + 1 ];
    wire    [  BA_BITS   - 1 : 0 ]  AddrBank    =   HADDR [ SADDR_BITS : ROW_BITS + COL_BITS + 1 ];

    // SDRAM command data
    reg     [ 4 : 0 ]    cmd;
    assign  { CKE, CSn, RASn, CASn, WEn } = cmd;

    localparam  CMD_NOP_NCKE        = 5'b00111,
                CMD_NOP             = 5'b10111,
                CMD_PRECHARGEALL    = 5'b10010,
                CMD_AUTOREFRESH     = 5'b10001,
                CMD_LOADMODEREG     = 5'b10000,
                CMD_ACTIVE          = 5'b10011,
                CMD_READ            = 5'b10101,
                CMD_WRITE           = 5'b10100;

    localparam  SDRAM_CAS           = 3'b010;            // CAS=2
    localparam  SDRAM_BURST_TYPE    = 1'b0;              // Sequential
    localparam  SDRAM_BURST_LEN     = 3'b001;            // BL=2

    localparam  SDRAM_MODE_A        = { { ADDR_BITS - 7 { 1'b0 } }, SDRAM_CAS, SDRAM_BURST_TYPE, SDRAM_BURST_LEN };
    localparam  SDRAM_MODE_B        = { BA_BITS {1'b0} };

    localparam  SDRAM_ALL_BANKS     = (1 << 10);         // A[10]=1
    localparam  SDRAM_AUTOPRCH_FLAG = (1 << 10);         // A[10]=1

    // set SDRAM i/o
    always @ (posedge HCLK) begin
        // command and addr
        case(Next)
            default             :   cmd <= CMD_NOP;
            S_INIT0_nCKE        :   cmd <= CMD_NOP_NCKE;
            S_INIT1_nCKE        :   cmd <= CMD_NOP_NCKE;
            S_INIT4_PRECHALL    :   begin cmd <= CMD_PRECHARGEALL;   ADDR <= SDRAM_ALL_BANKS; end
            S_INIT7_AUTOREF     :   cmd <= CMD_AUTOREFRESH;
            S_INIT9_LMR         :   begin cmd <= CMD_LOADMODEREG;    ADDR <= SDRAM_MODE_A; BA <= SDRAM_MODE_B; end

            S_READ0_ACT         :   begin cmd <= CMD_ACTIVE;         ADDR <= AddrRow;     BA <= AddrBank; end
            S_READ2_READ        :   begin cmd <= CMD_READ;           ADDR <= AddrColumn | SDRAM_AUTOPRCH_FLAG; end

            S_WRITE0_ACT        :   begin cmd <= CMD_ACTIVE;         ADDR <= AddrRow;     BA <= AddrBank; end
            S_WRITE2_WR0        :   begin cmd <= CMD_WRITE;          ADDR <= AddrColumn | SDRAM_AUTOPRCH_FLAG; end

            S_AREF0_AUTOREF     :   cmd <= CMD_AUTOREFRESH;
        endcase

        //write data
        case(Next)
            default             :   DQreg <= { DQ_BITS { 1'bz }};
            S_WRITE2_WR0        :   DQreg <= HWDATA [ 15:0  ];
            S_WRITE3_WR1        :   DQreg <= HWDATA [ 31:16 ];
        endcase

        //read data
        case(State)
            default             :   ;
            S_READ4_RD0         :   HRDATA [ 15:0  ] <= DQ;
            S_READ5_RD1         :   HRDATA [ 31:16 ] <= DQ;
        endcase

        //data mask
        casez( { Next, HSIZE_old, ByteNum } )
            default:                                DQM <= 2'b00;
            { S_WRITE2_WR0, HSIZE_X8,   2'b00 } :   DQM <= 2'b10;
            { S_WRITE2_WR0, HSIZE_X8,   2'b01 } :   DQM <= 2'b01;
            { S_WRITE2_WR0, HSIZE_X8,   2'b1? } :   DQM <= 2'b11;
            { S_WRITE3_WR1, HSIZE_X8,   2'b0? } :   DQM <= 2'b11;
            { S_WRITE3_WR1, HSIZE_X8,   2'b10 } :   DQM <= 2'b10;
            { S_WRITE3_WR1, HSIZE_X8,   2'b11 } :   DQM <= 2'b01;

            { S_WRITE2_WR0, HSIZE_X16,  2'b0? } :   DQM <= 2'b00;
            { S_WRITE2_WR0, HSIZE_X16,  2'b1? } :   DQM <= 2'b11;
            { S_WRITE3_WR1, HSIZE_X16,  2'b0? } :   DQM <= 2'b11;
            { S_WRITE3_WR1, HSIZE_X16,  2'b1? } :   DQM <= 2'b00;
        endcase
    end

endmodule
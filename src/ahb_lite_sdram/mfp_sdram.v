
/* Simple SDRAM controller for MIPSfpga+ system AHB-Lite bus
 * Copyright(c) 2017 Stanislav Zhelnio
 * https://github.com/zhelnio/ahb_lite_sdram
 */
`include "mfp_sdram.vh"

module mfp_sdram
(
    //SDRAM controller clock domain signals
    input                                   SDRAM_CLK,
    input                                   SDRAM_RSTn,

    //cmd & addr FIFO reader side
    output reg                              CFIFO_REN,
    input      [ `SDRAM_CMD_FIFO_DATA_WIDTH - 1 : 0 ] CFIFO_RDATA,
    input                                   CFIFO_REMPTY,

    //write data to memory FIFO reader side
    output reg                              WFIFO_REN,
    input      [                   31 : 0 ] WFIFO_RDATA,
    input                                   WFIFO_REMPTY,

    //read data from memory FIFO writer side
    output reg                              RFIFO_WEN,
    output reg [                   31 : 0 ] RFIFO_WDATA,
    input                                   RFIFO_WFULL,

    //SDRAM side
    output                                  SDRAM_CKE,
    output                                  SDRAM_CSn,
    output                                  SDRAM_RASn,
    output                                  SDRAM_CASn,
    output                                  SDRAM_WEn,
    output     [ `SDRAM_ADDR_BITS - 1 : 0 ] SDRAM_ADDR,
    output     [ `SDRAM_BA_BITS   - 1 : 0 ] SDRAM_BA,
    inout      [ `SDRAM_DQ_BITS   - 1 : 0 ] SDRAM_DQ,
    output reg [ `SDRAM_DM_BITS   - 1 : 0 ] SDRAM_DQM
);

    //FSM states
    localparam  S_IDLE              = 6'h0,    /* Inited and waiting for command in FIFO */

                S_INIT0_nCKE        = 6'h1,    /* First step after HW reset */
                S_INIT1_nCKE        = 6'h2,    /* Holding CKE LOW for `SDRAM_DELAY_nCKE before init steps */
                S_INIT2_CKE         = 6'h3,    /* Bringing CKE HIGH */
                S_INIT3_NOP         = 6'h4,    /* NOP after CKE is HIGH */
                S_INIT4_PRECHALL    = 6'h5,    /* Doing PRECHARGE */
                S_INIT5_NOP         = 6'h6,    /* Waiting for `SDRAM_DELAY_tRP after PRECHARGE */
                S_INIT6_PREREF      = 6'h7,    /* Setting AUTO_REFRESH count*/
                S_INIT7_AUTOREF     = 6'h8,    /* Doing AUTO_REFRESH */
                S_INIT8_NOP         = 6'h9,    /* Waiting for `SDRAM_DELAY_tRFC after AUTO_REFRESH */
                S_INIT9_LMR         = 6'ha,    /* Doing LOAD_MODE_REGISTER with CAS=2, BL=2, Seq  */
                S_INIT10_NOP        = 6'hb,    /* Waiting for `SDRAM_DELAY_tMRD after LOAD_MODE_REGISTER */

                S_READ0_ACT         = 6'h10,   /* Doing ACTIVE */
                S_READ1_NOP         = 6'h11,   /* Waiting for `SDRAM_DELAY_tRCD after ACTIVE */
                S_READ2_READ        = 6'h12,   /* Doing READ with Auto precharge */
                S_READ3_NOP         = 6'h13,   /* Waiting for `SDRAM_DELAY_tCAS after READ */
                S_READ4_RD0         = 6'h14,   /* Reading 1st word */
                S_READ5_RD1         = 6'h15,   /* Reading 2nd word */
                S_READ6_NOP         = 6'h16,   /* Waiting for `SDRAM_DELAY_afterREAD - it depends on tRC */

                S_WRITE0_WAIT       = 6'h20,   /* Wait for data to write */
                S_WRITE0_ACT        = 6'h21,   /* Doing ACTIVE */
                S_WRITE1_NOP        = 6'h22,   /* Waiting for `SDRAM_DELAY_tRCD after ACTIVE */
                S_WRITE2_WR0        = 6'h23,   /* Doing Write with Auto precharge, writing 1st word */
                S_WRITE3_WR1        = 6'h24,   /* Writing 2nd word */
                S_WRITE4_NOP        = 6'h25,   /* Waiting for `SDRAM_DELAY_afterWRITE - it depends on tRC */

                S_AREF0_AUTOREF     = 6'h30,   /* Doing AUTO_REFRESH */
                S_AREF1_NOP         = 6'h31,   /* Waiting for `SDRAM_DELAY_tRFC after AUTO_REFRESH */

                S_CMD0_GET          = 6'h32;   /* Get command from command FIFO */

    localparam  LD_SIZE = 25,       //long delay counter size
                SD_SIZE = 5,        //short delay counter size
                RP_SIZE = 4;        //operation repeat counter

    wire    [  5 : 0 ]              State;
    reg     [  5 : 0 ]              Next;

    mfp_register_r #(.WIDTH(6), .RESET(S_INIT0_nCKE)) State_r(SDRAM_CLK, SDRAM_RSTn, Next, 1'b1, State);

    wire    [ LD_SIZE - 1 : 0 ]     longDelay;
    reg     [ LD_SIZE - 1 : 0 ]     longDelayNext;
    wire    [ SD_SIZE - 1 : 0 ]     shortDelay;
    reg     [ SD_SIZE - 1 : 0 ]     shortDelayNext;
    wire    [ RP_SIZE - 1 : 0 ]     repeatCnt;
    reg     [ RP_SIZE - 1 : 0 ]     repeatCntNext;

    wire    NeedRefresh         = (longDelay  == 25'b0);
    wire    DelayFinished       = (shortDelay ==  5'b0);
    wire    BigDelayFinished    = (longDelay  == 25'b0);
    wire    RepeatsFinished     = (repeatCnt  ==  4'b0);
    
    mfp_register_r #(.WIDTH(25)) longDelay_r(SDRAM_CLK, SDRAM_RSTn, longDelayNext, 1'b1, longDelay);
    mfp_register_r #(.WIDTH(5)) shortDelay_r(SDRAM_CLK, SDRAM_RSTn, shortDelayNext, 1'b1, shortDelay);
    mfp_register_r #(.WIDTH(4)) repeatCnt_r(SDRAM_CLK, SDRAM_RSTn, repeatCntNext, 1'b1, repeatCnt);

    wire    [ 31 : 0 ]  CADDR      = CFIFO_RDATA[31:0 ];
    wire    [  2 : 0 ]  CSIZE      = CFIFO_RDATA[34:32];
    wire                CWRITE     = CFIFO_RDATA[35];
    wire                NeedAction = ~CFIFO_REMPTY;

    always @ (*) begin
        //State change decision
        Next = State;
        case(State)
            default             :   ;
            S_IDLE              :   Next = NeedAction ? S_CMD0_GET : (
                                           NeedRefresh ? S_AREF0_AUTOREF : S_IDLE );

            S_INIT0_nCKE        :   Next = S_INIT1_nCKE;
            S_INIT1_nCKE        :   Next = BigDelayFinished ? S_INIT2_CKE : S_INIT1_nCKE;
            S_INIT2_CKE         :   Next = S_INIT3_NOP;
            S_INIT3_NOP         :   Next = S_INIT4_PRECHALL;
            S_INIT4_PRECHALL    :   Next = (`SDRAM_DELAY_tRP == 0) ? S_INIT6_PREREF : S_INIT5_NOP;
            S_INIT5_NOP         :   Next = DelayFinished ? S_INIT6_PREREF : S_INIT5_NOP;
            S_INIT6_PREREF      :   Next = S_INIT7_AUTOREF;
            S_INIT7_AUTOREF     :   Next = S_INIT8_NOP;
            S_INIT8_NOP         :   Next = ~DelayFinished  ? S_INIT8_NOP : (
                                           RepeatsFinished ? S_INIT9_LMR : S_INIT7_AUTOREF );
            S_INIT9_LMR         :   Next = S_INIT10_NOP;
            S_INIT10_NOP        :   Next = ~DelayFinished ? S_INIT10_NOP : S_IDLE;

            S_CMD0_GET          :   Next = ~CWRITE ? S_READ0_ACT : (
                                            WFIFO_REMPTY ? S_WRITE0_WAIT : S_WRITE0_ACT);

            S_READ0_ACT         :   Next = S_READ1_NOP;
            S_READ1_NOP         :   Next = DelayFinished ? S_READ2_READ : S_READ1_NOP;
            S_READ2_READ        :   Next = (`SDRAM_DELAY_tCAS == 0) ? S_READ4_RD0 : S_READ3_NOP;
            S_READ3_NOP         :   Next = DelayFinished ? S_READ4_RD0 : S_READ3_NOP;
            S_READ4_RD0         :   Next = S_READ5_RD1;
            S_READ5_RD1         :   Next = (`SDRAM_DELAY_afterREAD != 0) ? S_READ6_NOP : (
                                           NeedRefresh  ? S_AREF0_AUTOREF : S_IDLE );
            S_READ6_NOP         :   Next = ~DelayFinished ? S_READ6_NOP : (
                                           NeedRefresh  ? S_AREF0_AUTOREF : S_IDLE );

            S_WRITE0_WAIT       :   Next = WFIFO_REMPTY ? S_WRITE0_WAIT : S_WRITE0_ACT;
            S_WRITE0_ACT        :   Next = S_WRITE1_NOP;
            S_WRITE1_NOP        :   Next = DelayFinished ? S_WRITE2_WR0 : S_WRITE1_NOP;
            S_WRITE2_WR0        :   Next = S_WRITE3_WR1;
            S_WRITE3_WR1        :   Next = (`SDRAM_DELAY_afterWRITE != 0) ? S_WRITE4_NOP : (
                                            NeedRefresh  ? S_AREF0_AUTOREF : S_IDLE );
            S_WRITE4_NOP        :   Next = ~DelayFinished ? S_WRITE4_NOP : (
                                           NeedRefresh  ? S_AREF0_AUTOREF : S_IDLE );

            S_AREF0_AUTOREF     :   Next = S_AREF1_NOP;
            S_AREF1_NOP         :   Next = ~DelayFinished ? S_AREF1_NOP : S_IDLE;
        endcase

        //short delay counter
        case(State)
            S_INIT4_PRECHALL    :   shortDelayNext = `SDRAM_DELAY_tRP - 1;
            S_INIT7_AUTOREF     :   shortDelayNext = `SDRAM_DELAY_tRFC;
            S_INIT9_LMR         :   shortDelayNext = `SDRAM_DELAY_tMRD;
            S_READ0_ACT         :   shortDelayNext = `SDRAM_DELAY_tRCD - 1;
            S_READ2_READ        :   shortDelayNext = `SDRAM_DELAY_tCAS - 1;
            S_READ5_RD1         :   shortDelayNext = `SDRAM_DELAY_afterREAD - 1;
            S_WRITE0_ACT        :   shortDelayNext = `SDRAM_DELAY_tRCD - 1;
            S_WRITE3_WR1        :   shortDelayNext = `SDRAM_DELAY_afterWRITE - 1;
            S_AREF0_AUTOREF     :   shortDelayNext = `SDRAM_DELAY_tRFC;
            default             :   shortDelayNext = DelayFinished ? 0 : shortDelay - 1;
        endcase

        //repeat operations counter
        case(State)
            S_INIT6_PREREF      :   repeatCntNext = `SDRAM_COUNT_initAutoRef;
            S_INIT7_AUTOREF     :   repeatCntNext = RepeatsFinished ? 0 : repeatCnt - 1;
            default             :   repeatCntNext = repeatCnt;
        endcase

        //long delay counter
        case(State)
            S_INIT0_nCKE        :   longDelayNext = `SDRAM_DELAY_nCKE;
            S_INIT7_AUTOREF     :   longDelayNext = `SDRAM_DELAY_tREF;
            S_AREF0_AUTOREF     :   longDelayNext = `SDRAM_DELAY_tREF;
            default             :   longDelayNext = BigDelayFinished ? 0 : longDelay - 1;
        endcase

        //fifo side
        CFIFO_REN = (State == S_IDLE) && NeedAction;
        WFIFO_REN = (State == S_WRITE0_ACT);
        RFIFO_WEN = (State == S_READ5_RD1);
    end

    // SDRAM IO side
    // SDRAM command data
    localparam  CMD_RESET           = 5'b01111,
                CMD_NOP_NCKE        = 5'b00111,
                CMD_NOP             = 5'b10111,
                CMD_PRECHARGEALL    = 5'b10010,
                CMD_AUTOREFRESH     = 5'b10001,
                CMD_LOADMODEREG     = 5'b10000,
                CMD_ACTIVE          = 5'b10011,
                CMD_READ            = 5'b10101,
                CMD_WRITE           = 5'b10100;

    wire    [ 4 : 0 ]   sdramCmd;
    reg     [ 4 : 0 ]   sdramCmdNext;
    assign  { SDRAM_CKE, SDRAM_CSn, SDRAM_RASn, SDRAM_CASn, SDRAM_WEn } = sdramCmd;

    mfp_register_r #(.WIDTH(5), .RESET(CMD_RESET)) cmd_r(SDRAM_CLK, SDRAM_RSTn, sdramCmdNext, 1'b1, sdramCmd);

    // set SDRAM command output
    always @ (*) begin
        case(Next)
            default             :   sdramCmdNext = CMD_NOP;
            S_INIT0_nCKE        :   sdramCmdNext = CMD_NOP_NCKE;
            S_INIT1_nCKE        :   sdramCmdNext = CMD_NOP_NCKE;
            S_INIT4_PRECHALL    :   sdramCmdNext = CMD_PRECHARGEALL;
            S_INIT7_AUTOREF     :   sdramCmdNext = CMD_AUTOREFRESH;
            S_INIT9_LMR         :   sdramCmdNext = CMD_LOADMODEREG;
            S_READ0_ACT         :   sdramCmdNext = CMD_ACTIVE;
            S_READ2_READ        :   sdramCmdNext = CMD_READ;
            S_WRITE0_ACT        :   sdramCmdNext = CMD_ACTIVE;
            S_WRITE2_WR0        :   sdramCmdNext = CMD_WRITE;
            S_AREF0_AUTOREF     :   sdramCmdNext = CMD_AUTOREFRESH;
        endcase
    end

    // address structure (example):
    // CADDR        (x32)   bbbb bbbb bbbb bbbb  bbbb bbbb bbbb bbbb
    // ByteNum      (x2 )   ---- ---- ---- ----  ---- ---- ---- --bb
    // AddrColumn   (x10)   ---- ---- ---- ----  ---- -bbb bbbb bb0-
    // AddrRow      (x13)   ---- ---- bbbb bbbb  bbbb b--- ---- ----
    // AddrBank     (x2 )   ---- --bb ---- ----  ---- ---- ---- ----
    //                    `SDRAM_BA_BITS==^^ <====`SDRAM_ROW_BITS===><=`SDRAM_COL_BITS=>x

    wire    [                   1 : 0 ]  ByteNum     =   CADDR [ 1 : 0 ];
    wire    [ `SDRAM_COL_BITS - 1 : 0 ]  AddrColumn  = { CADDR [ `SDRAM_COL_BITS : 2 ] , 1'b0 };
    wire    [ `SDRAM_ROW_BITS - 1 : 0 ]  AddrRow     =   CADDR [ `SDRAM_ROW_BITS + `SDRAM_COL_BITS : `SDRAM_COL_BITS + 1 ];
    wire    [ `SDRAM_BA_BITS  - 1 : 0 ]  AddrBank    =   CADDR [ `SDRAM_SADDR_BITS : `SDRAM_ROW_BITS + `SDRAM_COL_BITS + 1 ];

    // SDRAM config data
    localparam  SDRAM_CAS           = 3'b010;            // CAS=2
    localparam  SDRAM_BURST_TYPE    = 1'b0;              // Sequential
    localparam  SDRAM_BURST_LEN     = 3'b001;            // BL=2

    localparam  SDRAM_MODE_A  = { { `SDRAM_ADDR_BITS - 7 { 1'b0 } }, SDRAM_CAS, SDRAM_BURST_TYPE, SDRAM_BURST_LEN };
    localparam  SDRAM_MODE_B  = { `SDRAM_BA_BITS {1'b0} };

    localparam  SDRAM_ALL_BANKS     = (1 << 10);         // A[10]=1
    localparam  SDRAM_AUTOPRCH_FLAG = (1 << 10);         // A[10]=1

    reg  [ `SDRAM_ADDR_BITS - 1 : 0 ]   sdramAddrNext;
    reg  [   `SDRAM_BA_BITS - 1 : 0 ]   sdramBaNext;

    mfp_register_r #(.WIDTH(`SDRAM_ADDR_BITS)) ADDR_r(SDRAM_CLK, SDRAM_RSTn, sdramAddrNext, 1'b1, SDRAM_ADDR);
    mfp_register_r #(.WIDTH(`SDRAM_BA_BITS))   BA_r(SDRAM_CLK, SDRAM_RSTn, sdramBaNext, 1'b1, SDRAM_BA);

    // set SDRAM addr and confit output
    always @ (*) begin
        case(Next)
            default             :   sdramAddrNext = SDRAM_ADDR;
            S_INIT4_PRECHALL    :   sdramAddrNext = SDRAM_ALL_BANKS;
            S_INIT9_LMR         :   sdramAddrNext = SDRAM_MODE_A;
            S_READ0_ACT         :   sdramAddrNext = AddrRow;
            S_READ2_READ        :   sdramAddrNext = AddrColumn | SDRAM_AUTOPRCH_FLAG;
            S_WRITE0_ACT        :   sdramAddrNext = AddrRow;
            S_WRITE2_WR0        :   sdramAddrNext = AddrColumn | SDRAM_AUTOPRCH_FLAG;
        endcase

        case(Next)
            default             :   sdramBaNext = SDRAM_BA;
            S_INIT9_LMR         :   sdramBaNext = SDRAM_MODE_B;
            S_READ0_ACT         :   sdramBaNext = AddrBank;
            S_WRITE0_ACT        :   sdramBaNext = AddrRow;
        endcase
    end

    // SDRAM data and mask output
    reg     [ `SDRAM_DQ_BITS - 1 : 0    ]  DQreg;
    assign  SDRAM_DQ = DQreg;

    localparam  HSIZE_X8    = 3'b000,
                HSIZE_X16   = 3'b001,
                HSIZE_X32   = 3'b010;

    always @ (posedge SDRAM_CLK) begin

        //write data
        case(Next)
            default             :   DQreg <= { `SDRAM_DQ_BITS { 1'bz }};
            S_WRITE2_WR0        :   DQreg <= WFIFO_RDATA [ 15:0  ];
            S_WRITE3_WR1        :   DQreg <= WFIFO_RDATA [ 31:16 ];
        endcase

        //read data
        case(Next)
            default             :   ;
            S_READ4_RD0         :   RFIFO_WDATA [ 15:0  ] <= SDRAM_DQ;
            S_READ5_RD1         :   RFIFO_WDATA [ 31:16 ] <= SDRAM_DQ;
        endcase

        //data mask
        casez( { Next, CSIZE, ByteNum } )
            default:                                SDRAM_DQM <= 2'b00;
            { S_WRITE2_WR0, HSIZE_X8,   2'b00 } :   SDRAM_DQM <= 2'b10;
            { S_WRITE2_WR0, HSIZE_X8,   2'b01 } :   SDRAM_DQM <= 2'b01;
            { S_WRITE2_WR0, HSIZE_X8,   2'b1? } :   SDRAM_DQM <= 2'b11;
            { S_WRITE3_WR1, HSIZE_X8,   2'b0? } :   SDRAM_DQM <= 2'b11;
            { S_WRITE3_WR1, HSIZE_X8,   2'b10 } :   SDRAM_DQM <= 2'b10;
            { S_WRITE3_WR1, HSIZE_X8,   2'b11 } :   SDRAM_DQM <= 2'b01;

            { S_WRITE2_WR0, HSIZE_X16,  2'b0? } :   SDRAM_DQM <= 2'b00;
            { S_WRITE2_WR0, HSIZE_X16,  2'b1? } :   SDRAM_DQM <= 2'b11;
            { S_WRITE3_WR1, HSIZE_X16,  2'b0? } :   SDRAM_DQM <= 2'b11;
            { S_WRITE3_WR1, HSIZE_X16,  2'b1? } :   SDRAM_DQM <= 2'b00;
        endcase
    end

endmodule

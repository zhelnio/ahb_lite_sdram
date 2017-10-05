/* Simple SDRAM controller for MIPSfpga+ system AHB-Lite bus
 * Copyright(c) 2016 Stanislav Zhelnio
 * https://github.com/zhelnio/ahb_lite_sdram
 */

`include "mfp_sdram.vh"

module ahb_lite_sdram
(
    //ABB-Lite side
    input                                    HCLK,
    input                                    HRESETn,
    input       [ 31 : 0 ]                   HADDR,
    input       [  2 : 0 ]                   HBURST,
    input                                    HSEL,
    input       [  2 : 0 ]                   HSIZE,
    input       [  1 : 0 ]                   HTRANS,
    input       [ 31 : 0 ]                   HWDATA,
    input                                    HWRITE,
    input                                    HREADY,
    output      [ 31 : 0 ]                   HRDATA,
    output                                   HREADYOUT,
    output                                   HRESP,

    //SDRAM controller clock domain signals
    input                                    SDRAM_CLK,
    input                                    SDRAM_RSTn,

    //SDRAM side
    output                                   SDRAM_CKE,
    output                                   SDRAM_CSn,
    output                                   SDRAM_RASn,
    output                                   SDRAM_CASn,
    output                                   SDRAM_WEn,
    output      [ `SDRAM_ADDR_BITS - 1 : 0 ] SDRAM_ADDR,
    output      [ `SDRAM_BA_BITS   - 1 : 0 ] SDRAM_BA,
    inout       [ `SDRAM_DQ_BITS   - 1 : 0 ] SDRAM_DQ,
    output      [ `SDRAM_DM_BITS   - 1 : 0 ] SDRAM_DQM
);
    //FIFO wires
    wire                                    CFIFO_REN;
    wire [ `SDRAM_CMD_FIFO_DATA_WIDTH - 1: 0 ] CFIFO_RDATA;
    wire                                    CFIFO_REMPTY;
    wire                                    CFIFO_WEN;
    wire [ `SDRAM_CMD_FIFO_DATA_WIDTH - 1: 0 ] CFIFO_WDATA;
    wire                                    CFIFO_WFULL;

    wire            WFIFO_REN;
    wire [ 31 : 0 ] WFIFO_RDATA;
    wire            WFIFO_REMPTY;
    wire            WFIFO_WEN;
    wire [ 31 : 0 ] WFIFO_WDATA;
    wire            WFIFO_WFULL;

    wire            RFIFO_REN;
    wire [ 31 : 0 ] RFIFO_RDATA;
    wire            RFIFO_REMPTY;
    wire            RFIFO_WEN;
    wire [ 31 : 0 ] RFIFO_WDATA;
    wire            RFIFO_WFULL;

    //cmd & addr to memory FIFO
    mfp_fifo_dc 
    #(
        .DATA_WIDTH( `SDRAM_CMD_FIFO_DATA_WIDTH ),
        .ADDR_WIDTH( `SDRAM_CMD_FIFO_ADDR_WIDTH ),
        .USED_SIZE ( `SDRAM_CMD_FIFO_USED_SIZE  )
    )
    cfifo
    (
        .WCLK    ( HCLK         ),
        .WRSTn   ( HRESETn      ),
        .WEN     ( CFIFO_WEN    ),
        .WDATA   ( CFIFO_WDATA  ),
        .WFULL   ( CFIFO_WFULL  ),

        .RCLK    ( SDRAM_CLK    ),
        .RRSTn   ( SDRAM_RSTn   ),
        .REN     ( CFIFO_REN    ),
        .RDATA   ( CFIFO_RDATA  ),
        .REMPTY  ( CFIFO_REMPTY )
    );

    // write data to memory FIFO
    mfp_fifo_dc 
    #(
        .DATA_WIDTH(                          32 ),
        .ADDR_WIDTH( `SDRAM_DATA_FIFO_ADDR_WIDTH ),
        .USED_SIZE ( `SDRAM_DATA_FIFO_USED_SIZE  )
    )
    wfifo
    (
        .WCLK    ( HCLK         ),
        .WRSTn   ( HRESETn      ),
        .WEN     ( WFIFO_WEN    ),
        .WDATA   ( WFIFO_WDATA  ),
        .WFULL   ( WFIFO_WFULL  ),

        .RCLK    ( SDRAM_CLK    ),
        .RRSTn   ( SDRAM_RSTn   ),
        .REN     ( WFIFO_REN    ),
        .RDATA   ( WFIFO_RDATA  ),
        .REMPTY  ( WFIFO_REMPTY )
    );

    //read data from memory FIFO
    mfp_fifo_dc 
    #(
        .DATA_WIDTH(                          32 ),
        .ADDR_WIDTH( `SDRAM_DATA_FIFO_ADDR_WIDTH ),
        .USED_SIZE ( `SDRAM_DATA_FIFO_USED_SIZE  )
    )
    rfifo
    (
        .WCLK    ( SDRAM_CLK    ),
        .WRSTn   ( SDRAM_RSTn   ),
        .WEN     ( RFIFO_WEN    ),
        .WDATA   ( RFIFO_WDATA  ),
        .WFULL   ( RFIFO_WFULL  ),

        .RCLK    ( HCLK         ),
        .RRSTn   ( HRESETn      ),
        .REN     ( RFIFO_REN    ),
        .RDATA   ( RFIFO_RDATA  ),
        .REMPTY  ( RFIFO_REMPTY )
    );

    mfp_sdram sdram
    (
        .SDRAM_CLK    ( SDRAM_CLK    ),
        .SDRAM_RSTn   ( SDRAM_RSTn   ),
        .CFIFO_REN    ( CFIFO_REN    ),
        .CFIFO_RDATA  ( CFIFO_RDATA  ),
        .CFIFO_REMPTY ( CFIFO_REMPTY ),
        .WFIFO_REN    ( WFIFO_REN    ),
        .WFIFO_RDATA  ( WFIFO_RDATA  ),
        .WFIFO_REMPTY ( WFIFO_REMPTY ),
        .RFIFO_WEN    ( RFIFO_WEN    ),
        .RFIFO_WDATA  ( RFIFO_WDATA  ),
        .RFIFO_WFULL  ( RFIFO_WFULL  ),
        .SDRAM_CKE    ( SDRAM_CKE    ),
        .SDRAM_CSn    ( SDRAM_CSn    ),
        .SDRAM_RASn   ( SDRAM_RASn   ),
        .SDRAM_CASn   ( SDRAM_CASn   ),
        .SDRAM_WEn    ( SDRAM_WEn    ),
        .SDRAM_ADDR   ( SDRAM_ADDR   ),
        .SDRAM_BA     ( SDRAM_BA     ),
        .SDRAM_DQ     ( SDRAM_DQ     ),
        .SDRAM_DQM    ( SDRAM_DQM    )
    );

    ahb_lite_sdram_fifo sdram_fifo
    (
        .HCLK         ( HCLK         ),
        .HRESETn      ( HRESETn      ),
        .HADDR        ( HADDR        ),
        .HBURST       ( HBURST       ),
        .HSEL         ( HSEL         ),
        .HSIZE        ( HSIZE        ),
        .HTRANS       ( HTRANS       ),
        .HWDATA       ( HWDATA       ),
        .HWRITE       ( HWRITE       ),
        .HREADY       ( HREADY       ),
        .HRDATA       ( HRDATA       ),
        .HREADYOUT    ( HREADYOUT    ),
        .HRESP        ( HRESP        ),
        .CFIFO_WEN    ( CFIFO_WEN    ),
        .CFIFO_WDATA  ( CFIFO_WDATA  ),
        .CFIFO_WFULL  ( CFIFO_WFULL  ),
        .WFIFO_WEN    ( WFIFO_WEN    ),
        .WFIFO_WDATA  ( WFIFO_WDATA  ),
        .WFIFO_WFULL  ( WFIFO_WFULL  ),
        .RFIFO_REN    ( RFIFO_REN    ),
        .RFIFO_RDATA  ( RFIFO_RDATA  ),
        .RFIFO_REMPTY ( RFIFO_REMPTY )
    );

endmodule


module ahb_lite_sdram_fifo
(
    //ABB-Lite side
    input                 HCLK,
    input                 HRESETn,
    input      [ 31 : 0 ] HADDR,
    input      [  2 : 0 ] HBURST,
    input                 HSEL,
    input      [  2 : 0 ] HSIZE,
    input      [  1 : 0 ] HTRANS,
    input      [ 31 : 0 ] HWDATA,
    input                 HWRITE,
    input                 HREADY,
    output     [ 31 : 0 ] HRDATA,
    output                HREADYOUT,
    output                HRESP,

    //cmd & addr FIFO writer side
    output                                           CFIFO_WEN,
    output     [ `SDRAM_CMD_FIFO_DATA_WIDTH - 1: 0 ] CFIFO_WDATA,
    input                                            CFIFO_WFULL,

    //write data to memory FIFO writer side
    output                WFIFO_WEN,
    output     [ 31 : 0 ] WFIFO_WDATA,
    input                 WFIFO_WFULL,

    //read data from memory FIFO reader side
    output                RFIFO_REN,
    input      [ 31 : 0 ] RFIFO_RDATA,
    input                 RFIFO_REMPTY
);

    localparam  S_IDLE          = 0,    // Nothing to do
                S_CMD0_WAIT     = 1,    // Waiting for previous commands
                S_CMD1_CMD      = 2,    // Sending command
                S_READ1_WAIT    = 3,    // Waiting for read result
                S_READ2_RD0     = 4,    // Getting read result
                S_WRITE0_WAIT   = 5,    // Waiting for write fifo release
                S_WRITE0_WR0    = 6;    // Writing data

    wire    [  3 : 0 ]  State;
    reg     [  3 : 0 ]  Next;
    mfp_register_r #(.WIDTH(4), .RESET(S_IDLE)) State_r(HCLK, HRESETn, Next, 1'b1, State);

    wire                HWRITE_old;
    wire    [ 31 : 0 ]  HADDR_old;
    wire    [  2 : 0 ]  HSIZE_old;
    wire                saveAddrPhase = (State == S_IDLE);  //big scope for optimization

    mfp_register_r #(.WIDTH(32), .RESET(S_IDLE)) HADDR_r(HCLK, HRESETn, HADDR,  saveAddrPhase, HADDR_old);
    mfp_register_r #(.WIDTH(3), .RESET(S_IDLE)) HSIZE_r(HCLK, HRESETn, HSIZE,  saveAddrPhase, HSIZE_old);
    mfp_register_r #(.WIDTH(1), .RESET(S_IDLE)) HWRITE_r(HCLK, HRESETn, HWRITE, saveAddrPhase, HWRITE_old);

    localparam  HTRANS_IDLE = 2'b0;
    wire        NeedAction = HTRANS != HTRANS_IDLE && HSEL && HREADY;

    always @(*) begin
        Next = State;
        case(State)
            S_IDLE        : Next = ~NeedAction ? S_IDLE :
                                   CFIFO_WFULL ? S_CMD0_WAIT : S_CMD1_CMD;
            S_CMD0_WAIT   : Next = CFIFO_WFULL ? S_CMD0_WAIT : S_CMD1_CMD;
            S_CMD1_CMD    : Next = HWRITE_old ? (WFIFO_WFULL ? S_WRITE0_WAIT : S_WRITE0_WR0)
                                              : (RFIFO_REMPTY ? S_READ1_WAIT : S_READ2_RD0);
            S_READ1_WAIT  : Next = RFIFO_REMPTY ? S_READ1_WAIT : S_READ2_RD0;
            S_READ2_RD0   : Next = S_IDLE;
            S_WRITE0_WAIT : Next = WFIFO_WFULL ? S_WRITE0_WAIT : S_WRITE0_WR0;
            S_WRITE0_WR0  : Next = S_IDLE;
        endcase
    end

    assign HREADYOUT            = (State == S_IDLE);
    assign HRESP                = 1'b1;
    assign HRDATA               = RFIFO_RDATA;
    assign CFIFO_WEN            = (State == S_CMD1_CMD);
    assign CFIFO_WDATA[31:0 ]   = HADDR_old;
    assign CFIFO_WDATA[34:32]   = HSIZE_old;
    assign CFIFO_WDATA[35]      = HWRITE_old;
    assign WFIFO_WEN            = (State == S_WRITE0_WR0);
    assign WFIFO_WDATA          = HWDATA;
    assign RFIFO_REN            = (State == S_READ2_RD0);

endmodule
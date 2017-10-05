
`include "mfp_sdram.vh"

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

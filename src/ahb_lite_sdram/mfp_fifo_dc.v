/* Dual clock FIFO
 * Copyright(c) 2016,  Stanislav Zhelnio
 * originaly based on:
 *     https://github.com/olofk/fifo/blob/master/rtl/verilog/dual_clock_fifo.v
 *     Copyright (c) 2001, Richard Herveille <richard@asics.ws> 
 *     Copyright (c) 2012, Stefan Kristiansson <stefan.kristiansson@saunalahti.fi>
 */

module mfp_fifo_dc
#(
    parameter DATA_WIDTH = 32,
              ADDR_WIDTH = 2,
              USED_SIZE  = (1 << ADDR_WIDTH) - 1    // realy used fifo buffer size
                                                    // 1 cell can not be used
)
(
    //push side
    input                           WCLK,
    input                           WRSTn,
    input                           WEN,
    input      [DATA_WIDTH - 1:0]   WDATA,
    output                          WFULL,

    //pop side
    input                           RCLK,
    input                           RRSTn,
    input                           REN,
    output     [DATA_WIDTH - 1:0]   RDATA,
    output                          REMPTY
);
    localparam MEMORY_SIZE = USED_SIZE + 1;

    function   [ADDR_WIDTH - 1:0]   grayCode;
        input  [ADDR_WIDTH - 1:0]   in;
        begin
            grayCode = { in[ADDR_WIDTH - 1  ],
                         in[ADDR_WIDTH - 2:0] ^ in[ADDR_WIDTH - 1:1] };
        end
    endfunction

    function   [ADDR_WIDTH - 1:0]   nextAddr;
        input  [ADDR_WIDTH - 1:0]   addr;
        input  [ADDR_WIDTH - 1:0]   inc;
        reg    [ADDR_WIDTH - 1:0]   next;
        begin
            next = addr + inc;
            nextAddr = (next < MEMORY_SIZE) ? next : next - MEMORY_SIZE;
        end
    endfunction

    //write addr chain
    wire [ADDR_WIDTH - 1:0] wAddr;          //write addr
    wire [ADDR_WIDTH - 1:0] wAddrGray;      //write addr gray code
    wire [ADDR_WIDTH - 1:0] wAddrGray_rd;   //write addr gray code in read clock domain
    wire [ADDR_WIDTH - 1:0] wAddrNext      = nextAddr(wAddr, 1);
    wire [ADDR_WIDTH - 1:0] wAddrNext2     = nextAddr(wAddr, 2);
    wire [ADDR_WIDTH - 1:0] wAddrGrayNext  = grayCode(wAddrNext);
    wire [ADDR_WIDTH - 1:0] wAddrGrayNext2 = grayCode(wAddrNext2);

    mfp_register_r   #(.WIDTH(ADDR_WIDTH)) wAddr_r    (WCLK, WRSTn, wAddrNext,     WEN, wAddr);
    mfp_register_r   #(.WIDTH(ADDR_WIDTH)) wAddrGray_r(WCLK, WRSTn, wAddrGrayNext, WEN, wAddrGray);
    mfp_synchronyzer #(.WIDTH(ADDR_WIDTH)) wAddrGray_s(RCLK, wAddrGray, wAddrGray_rd);

    //read addr chain
    wire [ADDR_WIDTH - 1:0] rAddr;          //read addr
    wire [ADDR_WIDTH - 1:0] rAddrGray;      //read addr gray code
    wire [ADDR_WIDTH - 1:0] rAddrGray_wd;   //read addr gray code in write clock domain
    wire [ADDR_WIDTH - 1:0] rAddrNext      = nextAddr(rAddr, 1'b1);
    wire [ADDR_WIDTH - 1:0] rAddrGrayNext  = grayCode(nextAddr(rAddr, 1'b1));

    mfp_register_r   #(.WIDTH(ADDR_WIDTH)) rAddr_r    (RCLK, RRSTn, rAddrNext,     REN, rAddr);
    mfp_register_r   #(.WIDTH(ADDR_WIDTH)) rAddrGray_r(RCLK, RRSTn, rAddrGrayNext, REN, rAddrGray);
    mfp_synchronyzer #(.WIDTH(ADDR_WIDTH)) rAddrGray_s(WCLK, rAddrGray, rAddrGray_wd);

    //write side full
    wire wFullNext = WEN ? (wAddrGrayNext2 == rAddrGray_wd)
                         : WFULL & (wAddrGrayNext == rAddrGray_wd);
    mfp_register_r   #(.WIDTH(1)) wFull_r (WCLK, WRSTn, wFullNext, 1'b1, WFULL);

    //read side empty
    wire rEmptyNext = REN ? (rAddrGrayNext == wAddrGray_rd)
                          : REMPTY & (rAddrGray == wAddrGray_rd);
    mfp_register_r   #(.WIDTH(1), .RESET(1)) rEmpty_r (RCLK, RRSTn, rEmptyNext, 1'b1, REMPTY);

    mfp_dual_clock_ram  
    #( 
        .ADDR_WIDTH(ADDR_WIDTH), 
        .DATA_WIDTH(DATA_WIDTH),
        .USED_SIZE(MEMORY_SIZE)
    )
    mem 
    (
        .read_clk     ( RCLK  ),
        .read_addr    ( rAddr ),
        .read_data    ( RDATA ),
        .read_enable  ( REN   ),
        .write_clk    ( WCLK  ),
        .write_addr   ( wAddr ),
        .write_data   ( WDATA ),
        .write_enable ( WEN   )
    ); 

endmodule

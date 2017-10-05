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
    input                                    HMASTLOCK,  // ignored
    input       [ 3:0]                       HPROT,      // ignored
    input                                    HSEL,
    input       [  2 : 0 ]                   HSIZE,
    input       [  1 : 0 ]                   HTRANS,
    input       [ 31 : 0 ]                   HWDATA,
    input                                    HWRITE,
    input                                    HREADY,
    output  reg [ 31 : 0 ]                   HRDATA,
    output                                   HREADYOUT,
    output                                   HRESP,
    input                                    SI_Endian,  // ignored

    //SDRAM controller clock domain signals
    input                                    SDRAM_CLK,
    input                                    SDRAM_RSTn,

    //SDRAM side
    output                                   SDRAM_CKE,
    output                                   SDRAM_CSn,
    output                                   SDRAM_RASn,
    output                                   SDRAM_CASn,
    output                                   SDRAM_WEn,
    output  reg [ `SDRAM_ADDR_BITS - 1 : 0 ] SDRAM_ADDR,
    output  reg [ `SDRAM_BA_BITS   - 1 : 0 ] SDRAM_BA,
    inout       [ `SDRAM_DQ_BITS   - 1 : 0 ] SDRAM_DQ,
    output  reg [ `SDRAM_DM_BITS   - 1 : 0 ] SDRAM_DQM
);
    wire            CFIFO_REN;
    wire [ 35 : 0 ] CFIFO_RDATA;
    wire            CFIFO_REMPTY;
    wire            CFIFO_WEN;
    wire [ 35 : 0 ] CFIFO_WDATA;
    wire            CFIFO_WFULL;

    wire            WFIFO_REN;
    wire [ 32 : 0 ] WFIFO_RDATA;
    wire            WFIFO_REMPTY;
    wire            WFIFO_WEN;
    wire [ 32 : 0 ] WFIFO_WDATA;
    wire            WFIFO_WFULL;

    wire            RFIFO_REN;
    wire [ 32 : 0 ] RFIFO_RDATA;
    wire            RFIFO_REMPTY;
    wire            RFIFO_WEN;
    wire [ 32 : 0 ] RFIFO_WDATA;
    wire            RFIFO_WFULL;

    //cmd & addr to memory FIFO
    mfp_fifo_dc 
    #(
        .DATA_WIDTH(35),
        .ADDR_WIDTH( 2),
        .USED_SIZE ( 2)
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
        .DATA_WIDTH(32),
        .ADDR_WIDTH( 3),
        .USED_SIZE ( 1)
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
        .DATA_WIDTH(32),
        .ADDR_WIDTH( 3),
        .USED_SIZE ( 1)
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

    mfp_sdram mem
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

endmodule

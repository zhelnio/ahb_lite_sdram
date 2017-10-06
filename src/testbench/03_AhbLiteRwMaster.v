/* Simple SDRAM controller for MIPSfpga+ system AHB-Lite bus
 * Copyright(c) 2016 Stanislav Zhelnio
 * https://github.com/zhelnio/ahb_lite_sdram
 */

// Testbench for AHB-Lite SDRAM controller HW test
`timescale 1ns / 1ps

module test_ahb_lite_rw_master;

    `include "sdr_parameters.vh"

    wire                        CKE;
    wire                        CSn;
    wire                        RASn;
    wire                        CASn;
    wire                        WEn;
    wire  [ ADDR_BITS - 1 : 0 ] ADDR;
    wire  [ BA_BITS - 1 : 0   ] BA;
    wire  [ DQ_BITS - 1 : 0   ] DQ;
    wire  [ DM_BITS - 1 : 0   ] DQM;

    //AHB-Lite
    reg                         HCLK;    
    reg                         HRESETn;
    wire  [ 31 : 0 ]            HADDR;      //  Address
    wire  [  2 : 0 ]            HBURST;     //  Burst Operation (0 -SINGLE, 2 -WRAP4)
    wire                        HSEL;       //  Chip select
    wire  [  2 : 0 ]            HSIZE;      //  Transfer Size (0 -x8,   1 -x16,     2 -x32)
    wire  [  1 : 0 ]            HTRANS;     //  Transfer Type (0 -IDLE, 2 -NONSEQ,  3-SEQ)
    wire  [ 31 : 0 ]            HWDATA;     //  Write data
    wire                        HWRITE;     //  Write request
    wire  [ 31 : 0 ]            HRDATA;     //  Read data
    wire                        HREADY;     //  Indicate the previous transfer is complete
    wire                        HRESP;      //  0 is OKAY, 1 is ERROR

    reg                         SDRAM_CLK_OUT;
    reg                         SDRAM_CLK;

    ahb_lite_sdram mem
    (
        .HCLK       (   HCLK        ),
        .HRESETn    (   HRESETn     ),
        .HADDR      (   HADDR       ),
        .HBURST     (   HBURST      ),
        .HSEL       (   HSEL        ),
        .HSIZE      (   HSIZE       ),
        .HTRANS     (   HTRANS      ),
        .HWDATA     (   HWDATA      ),
        .HWRITE     (   HWRITE      ),
        .HRDATA     (   HRDATA      ),
        .HREADYOUT  (   HREADY      ),
        .HREADY     (   1'b1        ),
        .HRESP      (   HRESP       ),

        .SDRAM_CLK  (   SDRAM_CLK   ),
        .SDRAM_RSTn (   HRESETn     ),

        .SDRAM_CKE  (   CKE         ),
        .SDRAM_CSn  (   CSn         ),
        .SDRAM_RASn (   RASn        ),
        .SDRAM_CASn (   CASn        ),
        .SDRAM_WEn  (   WEn         ),
        .SDRAM_ADDR (   ADDR        ),
        .SDRAM_BA   (   BA          ),
        .SDRAM_DQ   (   DQ          ),
        .SDRAM_DQM  (   DQM         )
    );

    //----------------------------------------------------------------------

    parameter tT = 20;
    parameter phaseShift = 2;

    initial SDRAM_CLK_OUT = 1; 
    initial SDRAM_CLK = 0;
    initial HCLK = 0;

    always #(tCK/2) SDRAM_CLK = ~SDRAM_CLK;
    always #(tT/2)  HCLK = ~HCLK; //main clock

    initial begin
        #(phaseShift) 
        forever SDRAM_CLK_OUT = #(tCK/2) ~SDRAM_CLK_OUT;
    end

    //----------------------------------------------------------------------

    sdr sdram0 (DQ, ADDR, BA, SDRAM_CLK_OUT, CKE, CSn, RASn, CASn, WEn, DQM);

    wire [ 31 : 0 ]             ERRCOUNT;
    wire [  7 : 0 ]             CHKCOUNT;
    wire                        S_WRITE;
    wire                        S_CHECK;
    wire                        S_SUCCESS;
    wire                        S_FAILED;

    ahb_lite_rw_master
    #(

    )
    master 
    (
        .HCLK       (   HCLK        ),
        .HRESETn    (   HRESETn     ),
        .HADDR      (   HADDR       ),
        .HBURST     (   HBURST      ),
        .HSEL       (   HSEL        ),
        .HSIZE      (   HSIZE       ),
        .HTRANS     (   HTRANS      ),
        .HWDATA     (   HWDATA      ),
        .HWRITE     (   HWRITE      ),
        .HRDATA     (   HRDATA      ),
        .HREADY     (   HREADY      ),
        .HRESP      (   HRESP       ),

        .ERRCOUNT   (   ERRCOUNT    ),
        .CHKCOUNT   (   CHKCOUNT    ),
        .S_WRITE    (   S_WRITE     ),
        .S_CHECK    (   S_CHECK     ),
        .S_SUCCESS  (   S_SUCCESS   ),
        .S_FAILED   (   S_FAILED    ),
        .STARTADDR  (   1           )
    );

    //----------------------------------------------------------------------

    initial begin
        begin
            HRESETn = 0;
            @(posedge HCLK);
            @(posedge HCLK);
            @(posedge HCLK);
            HRESETn = 1;

        end

        #70000 //waiting for auto_refresh
        $stop;
        $finish;
    end

endmodule

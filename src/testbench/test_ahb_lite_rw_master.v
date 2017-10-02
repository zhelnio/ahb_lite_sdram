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

    //`define CLOCK_50_MHZ 1

    ahb_lite_sdram 
    #(
        .DELAY_nCKE (1000),
        .DELAY_tREF (4000)

        `ifndef CLOCK_50_MHZ
        ,
        .DELAY_tRP          ( 1     ),
        .DELAY_tRFC         ( 7     ),
        .DELAY_tRCD         ( 2     ),
        .DELAY_tCAS         ( 1     ),
        .DELAY_afterREAD    ( 3     ),
        .DELAY_afterWRITE   ( 5     )
        `endif
    ) 
    mem
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

        .CKE        (   CKE         ),
        .CSn        (   CSn         ),
        .RASn       (   RASn        ),
        .CASn       (   CASn        ),
        .WEn        (   WEn         ),
        .ADDR       (   ADDR        ),
        .BA         (   BA          ),
        .DQ         (   DQ          ),
        .DQM        (   DQM         )
    );

    //----------------------------------------------------------------------
    reg     MCLK;   //memory clock

    `ifdef CLOCK_50_MHZ
        parameter tT = 20;
        parameter phaseShift = 12;
    `else
        parameter tT = tCK;
        parameter phaseShift = 2;
    `endif

    initial begin
        MCLK = 1; 
        #(phaseShift) 
        forever MCLK = #(tT/2) ~MCLK;
    end

    always #(tT/2) HCLK = ~HCLK; //main clock

    //----------------------------------------------------------------------

    sdr sdram0 (DQ, ADDR, BA, MCLK, CKE, CSn, RASn, CASn, WEn, DQM);

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
            HCLK    = 0;
            HRESETn = 0;        
            @(posedge HCLK);
            @(posedge HCLK);
            HRESETn = 1;

        end

        #70000 //waiting for auto_refresh
        $stop;
        $finish;
    end

endmodule

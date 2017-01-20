

// Testbench for AHB-Lite master emulator

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

    ahb_lite_sdram 
    #(
        .DELAY_nCKE (1000),
        .DELAY_tREF (4000)
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
        .HREADY     (   HREADY      ),
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

    //memory clock
    reg             MCLK;
    initial begin
        MCLK = 1; #2 //phase shift from main clock
        forever MCLK = #(tCK/2) ~MCLK;
    end

    sdr sdram0 (DQ, ADDR, BA, MCLK, CKE, CSn, RASn, CASn, WEn, DQM);

    wire [ 31 : 0 ]              ERRCOUNT;

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

        .ERRCOUNT   (   ERRCOUNT    )
    );

    //main clock
    always #(tCK/2) HCLK = ~HCLK;

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

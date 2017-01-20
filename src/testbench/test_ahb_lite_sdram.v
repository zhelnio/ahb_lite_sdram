// Testbench for AHB-Lite master emulator

`timescale 1ns / 1ps

module test_ahb_lite_sdram;

    `include "sdr_parameters.vh"
    `include "ahb_lite.vh"

    wire                      CKE;
    wire                      CSn;
    wire                      RASn;
    wire                      CASn;
    wire                      WEn;
    wire  [ADDR_BITS - 1 : 0] ADDR;
    wire  [BA_BITS - 1 : 0]   BA;
    wire  [DQ_BITS - 1 : 0]   DQ;
    wire  [DM_BITS - 1 : 0]   DQM;

    ahb_lite_sdram 
    #(
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

    //main clock
    always #(tCK/2) HCLK = ~HCLK;

    initial begin
        begin
            HCLK    = 0;
            HRESETn = 0;        
            @(posedge HCLK);
            @(posedge HCLK);
            HRESETn = 1;

            @(posedge HCLK);
            ahbPhaseFst(0, 0, St_x);
            ahbPhase   (4, 1, St_x);
            ahbPhase   (8, 1, 4);
            ahbPhase   (4, 0, 8);
            ahbPhase   (8, 0, St_x);
            ahbPhaseLst(8, 0, St_x);

            @(posedge HCLK);
            @(posedge HCLK);
        end

        #70000 //waiting for auto_refresh
        $stop;
        $finish;
    end

endmodule

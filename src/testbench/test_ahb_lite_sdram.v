/* Simple SDRAM controller for MIPSfpga+ system AHB-Lite bus
 * Copyright(c) 2016 Stanislav Zhelnio
 * https://github.com/zhelnio/ahb_lite_sdram
 */

// Testbench for AHB-Lite master sdram controller
`timescale 1ns / 100ps

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

    reg                       SDRAM_CLK_OUT;
    reg                       SDRAM_CLK;

    ahb_lite_sdram
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

    //memory clock
    initial SDRAM_CLK = 0;
    always #(tCK/2) SDRAM_CLK = ~SDRAM_CLK;

    initial begin
        SDRAM_CLK_OUT = 1; #2 //phase shift from main clock 
        forever SDRAM_CLK_OUT = #(tCK/2) ~SDRAM_CLK_OUT;
    end

    sdr sdram0 (DQ, ADDR, BA, SDRAM_CLK_OUT, CKE, CSn, RASn, CASn, WEn, DQM);

    //main clock
    localparam tHCLK = 20;
    always #(tHCLK/2) HCLK = ~HCLK;

    initial begin
        begin
            HCLK    = 0;
            HRESETn = 0;        
            @(posedge HCLK);
            @(posedge HCLK);
            HRESETn = 1;

            @(posedge HCLK);
            ahbPhaseFst(0,  READ,  HSIZE_X32, St_x);
            ahbPhase   (4,  WRITE, HSIZE_X32, St_x);
            ahbPhase   (8,  WRITE, HSIZE_X32, 32'h76543210);
            ahbPhase   (4,  READ,  HSIZE_X32, 32'hFEDCAB98);
            ahbPhase   (8,  READ,  HSIZE_X32, St_x);

            ahbPhase   (4,  WRITE, HSIZE_X16, St_x);
            ahbPhase   (6,  WRITE, HSIZE_X16, 32'h7654AAAA);
            ahbPhase   (4,  READ,  HSIZE_X32, 32'hBBBB3210);
            
            ahbPhase   (4,  WRITE, HSIZE_X8,  St_x);
            ahbPhase   (6,  WRITE, HSIZE_X8,  32'h111111CC);
            ahbPhase   (9,  WRITE, HSIZE_X8,  32'h22DD2222);
            ahbPhase   (11, WRITE, HSIZE_X8,  32'h3333EE33);
            ahbPhase   (4,  READ,  HSIZE_X32, 32'hFF444444);
            
            ahbPhase   (8,  READ,  HSIZE_X32, St_x);
            ahbPhaseLst(8,  READ,  HSIZE_X32, St_x);

            @(posedge HCLK);
            @(posedge HCLK);
        end

        #70000 //waiting for auto_refresh
        $stop;
        $finish;
    end

endmodule

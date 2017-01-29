/* Simple SDRAM controller for MIPSfpga+ system AHB-Lite bus
 * Copyright(c) 2016 Stanislav Zhelnio
 * https://github.com/zhelnio/ahb_lite_sdram
 */

// Testbench for AHB-Lite master emulator
`timescale 1ns / 1ps

module test_ahb_lite_mem;

    `include "sdr_parameters.vh"
    `include "ahb_lite.vh"

    ahb_lite_mem mem
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
        .HRESP      (   HRESP       )
    );

    always #(tCK/2) HCLK = ~HCLK;

    initial begin
        begin
            
            HRESETn = 0;        
            @(posedge HCLK);
            @(posedge HCLK);
            HRESETn = 1;

            @(posedge HCLK);
            ahbPhaseFst(2, 0, St_x);
            ahbPhase   (4, 1, St_x);
            ahbPhase   (6, 1, 4);
            ahbPhase   (4, 0, 6);
            ahbPhase   (6, 0, St_x);
            ahbPhaseLst(6, 0, St_x);

            @(posedge HCLK);
            @(posedge HCLK);
        end
        $stop;
        $finish;
    end

endmodule


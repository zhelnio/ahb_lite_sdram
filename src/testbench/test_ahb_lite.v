// Testbench for AHB-Lite master emulator

`timescale 1ns / 1ps

module test_ahb_lite;

    `include "sdr_parameters.vh"
    `include "ahb_lite.vh"

    always #(tCK/2) HCLK = ~HCLK;

    initial begin
        begin
            @(posedge HCLK);
            ahbPhase   (1, 0, St_x);
            ahbPhase   (2, 1, St_x);
            ahbPhase   (3, 0, 2);
            ahbPhase   (4, 0, St_x);

            @(posedge HCLK);
            @(posedge HCLK);
        end
        $stop;
        $finish;
    end

endmodule

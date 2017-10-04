

module mfp_synchronyzer
#(
    parameter WIDTH = 1
)
(
    input                       clk,
    input      [ WIDTH - 1 : 0] d,
    output reg [ WIDTH - 1 : 0] q
);
    reg        [ WIDTH - 1 : 0] buffer;

    always @ (posedge clk) begin
        buffer <= d;
        q      <= buffer;
    end

endmodule
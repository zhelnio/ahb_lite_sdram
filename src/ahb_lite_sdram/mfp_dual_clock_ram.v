

module mfp_dual_clock_ram
# (
    parameter ADDR_WIDTH = 6,
              DATA_WIDTH = 32,
              USED_SIZE  = (1 << ADDR_WIDTH)
)
(
    //reader
    input                         read_clk,
    input      [ADDR_WIDTH - 1:0] read_addr,
    output reg [DATA_WIDTH - 1:0] read_data,
    input                         read_enable,

    //writer
    input                         write_clk,
    input      [ADDR_WIDTH - 1:0] write_addr,
    input      [DATA_WIDTH - 1:0] write_data,
    input                         write_enable
    
);
    reg [DATA_WIDTH - 1:0] ram [USED_SIZE - 1:0];

    always @ (posedge write_clk)
        if (write_enable)
            ram [write_addr] <= write_data;

    always @ (posedge read_clk)
        if (read_enable)
            read_data <= ram [read_addr];

endmodule
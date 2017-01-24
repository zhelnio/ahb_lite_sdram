/* Simple SDRAM controller for MIPSfpga+ system AHB-Lite bus
 * Copyright(c) 2016 Stanislav Zhelnio
 * https://github.com/zhelnio/ahb_lite_sdram
 */

// simply ram with HREADY support
module ahb_lite_mem
(
    //ABB-Lite side
    input                       HCLK,    
    input                       HRESETn,
    input       [31:0]          HADDR,
    input       [ 2:0]          HBURST,
    input                       HSEL,
    input       [ 2:0]          HSIZE,
    input       [ 1:0]          HTRANS,
    input       [31:0]          HWDATA,
    input                       HWRITE,
    output  reg [31:0]          HRDATA,
    output                      HREADY,
    output                      HRESP
);
    assign HRESP  = 1'b0;

    parameter   S_INIT          = 0,
                S_IDLE          = 1,
                S_READ          = 2,
                S_WRITE         = 3,
                S_AUTO_REFRESH  = 4;

    reg     [4:0]       State, Next;
    reg     [31:0]      HADDR_old;
    reg                 HWRITE_old;

    assign  HREADY = (State == S_IDLE);
    wire    NeedAction = (HADDR_old != HADDR || HWRITE_old != HWRITE);

    always @ (posedge HCLK) begin
        if (~HRESETn)
            State <= S_INIT;
        else
            State <= Next;
    end

    always @ (*) begin
        Next = State;
        case(State)
            S_INIT:         Next = S_IDLE;
            S_IDLE:         Next = ~NeedAction ? S_IDLE : (HWRITE ? S_WRITE : S_READ);
            S_READ:         Next = S_IDLE;
            S_WRITE:        Next = S_IDLE;
            S_AUTO_REFRESH: Next = S_IDLE;
        endcase
    end

    reg [31:0] ram [6:0];

    always @ (posedge HCLK) begin
        if(State == S_INIT) begin
            HADDR_old   <= 32'b0;
            HWRITE_old  <= 1'b0;
        end

        if(State == S_IDLE && HSEL) begin
            HADDR_old   <= HADDR;
            HWRITE_old  <= HWRITE;
        end

        if(State == S_READ)
            HRDATA <= ram[HADDR_old];
            
        if(State == S_WRITE)
            ram[HADDR_old] <= HWDATA;
    end

endmodule

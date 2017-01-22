/* Simple SDRAM controller for MIPSfpga+ system AHB-Lite bus
 * Copyright(c) 2016 Stanislav Zhelnio
 * https://github.com/zhelnio/ahb_lite_sdram
 */

//AHB-Lite transmit tasks for testbench

reg             HCLK;    
reg             HRESETn;
reg     [31:0]  HADDR;      //  Address
reg     [ 2:0]  HBURST;     //  Burst Operation (0 -SINGLE, 2 -WRAP4)
reg             HSEL;       //  Chip select
reg     [ 2:0]  HSIZE;      //  Transfer Size (0 -x8,   1 -x16,     2 -x32)
reg     [ 1:0]  HTRANS;     //  Transfer Type (0 -IDLE, 2 -NONSEQ,  3-SEQ)
reg     [31:0]  HWDATA;     //  Write data
reg             HWRITE;     //  Write request
wire    [31:0]  HRDATA;     //  Read data
wire            HREADY;     //  Indicate the previous transfer is complete
wire            HRESP;      //  0 is OKAY, 1 is ERROR

`ifdef SIMULATION

parameter       hi_z = {32{1'bz}};  // Hi-Z
parameter       St_x = {32{1'bx}};  // X-State

initial begin
    HCLK        = 1'b0;
    HRESETn     = 1'b1;
    HADDR       = 32'b0;
    HBURST      = 1'b0;     
    HSEL        = 1'b0;     
    HSIZE       = 3'b010;   
    HTRANS      = 2'b00;    
    HWDATA      = St_x;
    HWRITE      = 1'b0;       
end

task ahbPhase;
    input [31:0]    iNextHADDR;
    input           iNextHWRITE;
    input [31:0]    iHWDATA;

    reg         HWRITE_old;
    reg [31:0]  HADDR_old;

    begin
        HWRITE_old  = HWRITE;
        HADDR_old   = HADDR;

        HSEL    = 1'b1;
        HADDR   = iNextHADDR;
        HWRITE  = iNextHWRITE;
        HWDATA  = HWRITE_old ? iHWDATA : St_x;

        @(posedge HCLK);

        if (~HREADY) begin
            @(posedge HREADY);
            @(posedge HCLK);
        end

        if (HWRITE_old)
            $display("%t WRITEN HADDR=%h HWDATA=%h",
                    $time, HADDR_old, HWDATA);
        else
            $display("%t READEN HADDR=%h HRDATA=%h",
                    $time, HADDR_old, HRDATA);
    end
endtask

task ahbPhaseFst;
    input [31:0]    iNextHADDR;
    input           iNextHWRITE;
    input [31:0]    iHWDATA;
    begin
        HTRANS  = 2'b10; 
        ahbPhase (iNextHADDR, iNextHWRITE, iHWDATA);
    end
endtask

task ahbPhaseLst;
    input [31:0]    iNextHADDR;
    input           iNextHWRITE;
    input [31:0]    iHWDATA;

    begin
        HTRANS  = 2'b00; 
        ahbPhase (iNextHADDR, iNextHWRITE, iHWDATA);
    end
endtask

`endif //SIMULATION
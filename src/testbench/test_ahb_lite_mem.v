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
            ahbPhase   (2, 0, St_x);
            ahbPhase   (4, 1, St_x);
            ahbPhase   (6, 1, 4);
            ahbPhase   (4, 0, 6);
            ahbPhase   (6, 0, St_x);
            ahbPhase   (6, 0, St_x);

            @(posedge HCLK);
            @(posedge HCLK);
        end
        $stop;
        $finish;
    end

endmodule

/*
parameter ADDR_BITS        =      13; // Set this parameter to control how many Address bits are used
parameter ROW_BITS         =      13; // Set this parameter to control how many Row bits are used
parameter COL_BITS         =      10; // Set this parameter to control how many Column bits are used
parameter DQ_BITS          =      16; // Set this parameter to control how many Data bits are used
parameter DM_BITS          =       2; // Set this parameter to control how many DM bits are used
parameter BA_BITS          =       2; // Bank bits
*/

module ahb_lite_mem
#(
    parameter ADDR_BITS = 13,
    parameter BA_BITS   = 2,
    parameter DQ_BITS   = 16,
    parameter DM_BITS   = 2
)
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
    output                      HRESP //,

    //SDRAM side
    /*
    output                      CKE,
    output                      CSn,
    output                      RASn,
    output                      CASn,
    output                      WEn,
    output  [ADDR_BITS - 1 : 0] ADDR,
    output  [BA_BITS - 1 : 0]   BA,
    inout   [DQ_BITS - 1 : 0]   DQ,
    output  [DM_BITS - 1 : 0]   DQM
    */
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

    reg [31:0] ram [4:0];

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



/*
`include "sdr_parameters.vh"

reg                     clk;                           // Clock
reg                     cke;                           // Synchronous Clock Enable
reg                     cs_n;                          // CS#
reg                     ras_n;                         // RAS#
reg                     cas_n;                         // CAS#
reg                     we_n;                          // WE#
reg [ADDR_BITS - 1 : 0] addr;                          // SDRAM Address
reg   [BA_BITS - 1 : 0] ba;                            // Bank Address
reg   [DQ_BITS - 1 : 0] dq;                            // SDRAM I/O
reg   [DM_BITS - 1 : 0] dqm;                           // Data Mask

wire  [DQ_BITS - 1 : 0] DQ = dq;

parameter            hi_z = {DQ_BITS{1'bz}};                  // Hi-Z

sdr sdram0 (DQ, addr, ba, clk, cke, cs_n, ras_n, cas_n, we_n, dqm);

initial begin
    clk = 1'b0;
    cke = 1'b0;
    cs_n = 1'b1;
    dq  = hi_z;
end

always #(tCK/2) clk = ~clk;

/*
always @ (posedge clk) begin
    $strobe("at time %t clk=%b cke=%b CS#=%b RAS#=%b CAS#=%b WE#=%b dqm=%b addr=%b ba=%b DQ=%d",
            $time, clk, cke, cs_n, ras_n, cas_n, we_n, dqm, addr, ba, DQ);
end
*/

/*
task active;
    input [ADDR_BITS - 1 : 0] bank;
    input  [ROW_BITS - 1 : 0] row;
    input   [DQ_BITS - 1 : 0] dq_in;
    begin
        cke   = 1;
        cs_n  = 0;
        ras_n = 0;
        cas_n = 1;
        we_n  = 1;
        dqm   = 0;
        ba    = bank;
        addr  = row;
        dq    = dq_in;
    end
endtask

task auto_refresh;
    begin
        cke   = 1;
        cs_n  = 0;
        ras_n = 0;
        cas_n = 0;
        we_n  = 1;
        dqm   = 0;
        //ba    = 0;
        //addr  = 0;
        dq    = hi_z;
    end
endtask

task burst_term;
    input [DQ_BITS - 1 : 0] dq_in;
    begin
        cke   = 1;
        cs_n  = 0;
        ras_n = 1;
        cas_n = 1;
        we_n  = 0;
        dqm   = 0;
        //ba    = 0;
        //addr  = 0;
        dq    = dq_in;
    end
endtask

task load_mode_reg;
    input [ADDR_BITS - 1 : 0] op_code;
    begin
        cke   = 1;
        cs_n  = 0;
        ras_n = 0;
        cas_n = 0;
        we_n  = 0;
        dqm   = 0;
        ba    = 0;
        addr  = op_code;
        dq    = hi_z;
    end
endtask

task nop;
    input [DM_BITS - 1 : 0] dqm_in;
    input [DQ_BITS - 1 : 0] dq_in;
    begin
        cke   = 1;
        cs_n  = 0;
        ras_n = 1;
        cas_n = 1;
        we_n  = 1;
        dqm   = dqm_in;
        //ba    = 0;
        //addr  = 0;
        dq    = dq_in;
    end
endtask

task precharge_bank_0;
    input [DM_BITS - 1 : 0] dqm_in;
    input [DQ_BITS - 1 : 0] dq_in;
    begin
        cke   = 1;
        cs_n  = 0;
        ras_n = 0;
        cas_n = 1;
        we_n  = 0;
        dqm   = dqm_in;
        ba    = 0;
        addr  = 0;
        dq    = dq_in;
    end
endtask

task precharge_bank_1;
    input [DM_BITS - 1 : 0] dqm_in;
    input [DQ_BITS - 1 : 0] dq_in;
    begin
        cke   = 1;
        cs_n  = 0;
        ras_n = 0;
        cas_n = 1;
        we_n  = 0;
        dqm   = dqm_in;
        ba    = 1;
        addr  = 0;
        dq    = dq_in;
    end
endtask

task precharge_bank_2;
    input [DM_BITS - 1 : 0] dqm_in;
    input [DQ_BITS - 1 : 0] dq_in;
    begin
        cke   = 1;
        cs_n  = 0;
        ras_n = 0;
        cas_n = 1;
        we_n  = 0;
        dqm   = dqm_in;
        ba    = 2;
        addr  = 0;
        dq    = dq_in;
    end
endtask

task precharge_bank_3;
    input [DM_BITS - 1 : 0] dqm_in;
    input [DQ_BITS - 1 : 0] dq_in;
    begin
        cke   = 1;
        cs_n  = 0;
        ras_n = 0;
        cas_n = 1;
        we_n  = 0;
        dqm   = dqm_in;
        ba    = 3;
        addr  = 0;
        dq    = dq_in;
    end
endtask

task precharge_all_bank;
    input [DM_BITS - 1 : 0] dqm_in;
    input [DQ_BITS - 1 : 0] dq_in;
    begin
        cke   = 1;
        cs_n  = 0;
        ras_n = 0;
        cas_n = 1;
        we_n  = 0;
        dqm   = dqm_in;
        ba    = 0;
        addr  = 1024;            // A10 = 1
        dq    = dq_in;
    end
endtask

task read;
    input   [BA_BITS - 1 : 0] bank;
    input [ADDR_BITS - 1 : 0] column;
    input   [DQ_BITS - 1 : 0] dq_in;
    input   [DM_BITS - 1 : 0] dqm_in;
    begin
        cke   = 1;
        cs_n  = 0;
        ras_n = 1;
        cas_n = 0;
        we_n  = 1;
        dqm   = dqm_in;
        ba    = bank;
        addr  = column;
        dq    = dq_in;
    end
endtask

task write;
    input   [BA_BITS - 1 : 0] bank;
    input [ADDR_BITS - 1 : 0] column;
    input   [DQ_BITS - 1 : 0] dq_in;
    input   [DM_BITS - 1 : 0] dqm_in;
    begin
        cke   = 1;
        cs_n  = 0;
        ras_n = 1;
        cas_n = 0;
        we_n  = 0;
        dqm   = dqm_in;
        ba    = bank;
        addr  = column;
        dq    = dq_in;
    end
endtask

initial begin
    begin
        // Initialize
        #tCK; nop    (0, hi_z);                 // Nop
        #tCK; nop    (0, hi_z);                 // Nop
        #tCK; nop    (0, hi_z);                 // Nop
        #tCK; nop    (0, hi_z);                 // Nop
        #tCK; nop    (0, hi_z);                 // Nop
        #tCK; nop    (0, hi_z);                 // Nop
        #tCK; nop    (0, hi_z);                 // Nop
        #tCK; nop    (0, hi_z);                 // Nop
        #tCK; nop    (0, hi_z);                 // Nop
        #tCK; nop    (0, hi_z);                 // Nop
        #tCK; precharge_all_bank(0, hi_z);      // Precharge ALL Bank
        #tCK; nop    (0, hi_z);                 // Nop
        #tCK; nop    (0, hi_z);                 // Nop
        #tCK; nop    (0, hi_z);                 // Nop
        #tCK; nop    (0, hi_z);                 // Nop
        #tCK; auto_refresh;                     // Auto Refresh
        #tCK; nop    (0, hi_z);                 // Nop
        #tCK; nop    (0, hi_z);                 // Nop
        #tCK; nop    (0, hi_z);                 // Nop
        #tCK; nop    (0, hi_z);                 // Nop
        #tCK; nop    (0, hi_z);                 // Nop
        #tCK; nop    (0, hi_z);                 // Nop
        #tCK; nop    (0, hi_z);                 // Nop
        #tCK; nop    (0, hi_z);                 // Nop
        #tCK; nop    (0, hi_z);                 // Nop
        #tCK; auto_refresh;                     // Auto Refresh
        #tCK; nop    (0, hi_z);                 // Nop
        #tCK; nop    (0, hi_z);                 // Nop
        #tCK; nop    (0, hi_z);                 // Nop
        #tCK; nop    (0, hi_z);                 // Nop
        #tCK; nop    (0, hi_z);                 // Nop
        #tCK; nop    (0, hi_z);                 // Nop
        #tCK; nop    (0, hi_z);                 // Nop
        #tCK; nop    (0, hi_z);                 // Nop
        #tCK; nop    (0, hi_z);                 // Nop
        #tCK; load_mode_reg (50);               // Load Mode: Lat = 3, BL = 4, Seq
        #tCK; nop    (0, hi_z);                 // Nop

        // Write with auto precharge to bank 0 (non-interrupt)
        #tCK; active (0, 0, hi_z);              // Active: Bank = 0, Row = 0
        #tCK; nop    (0, hi_z);                 // Nop
        #tCK; nop    (0, hi_z);                 // Nop
        #tCK; write  (0, 1024, $random, 0);     // Write : Bank = 0, Col = 0, Dqm = 0, Auto Precharge
        #tCK; nop    (0, $random);              // Nop
        #tCK; nop    (0, $random);              // Nop
        #tCK; nop    (0, $random);              // Nop
        #tCK; nop    (0, hi_z);                 // Nop

        // Write with auto precharge to bank 1 (non-interrupt)
        #tCK; active (1, 0, hi_z);              // Active: Bank = 1, Row = 0
        #tCK; nop    (0, hi_z);                 // Nop
        #tCK; nop    (0, hi_z);                 // Nop
        #tCK; write  (1, 1024, $random, 0);     // Write : Bank = 1, Col = 0, Dqm = 0, Auto precharge
        #tCK; nop    (0, $random);              // Nop
        #tCK; nop    (0, $random);              // Nop
        #tCK; nop    (0, $random);              // Nop
        #tCK; nop    (0, hi_z);                 // Nop

        // Write with auto precharge to bank 2 (non-interrupt)
        #tCK; active (2, 0, hi_z);              // Active: Bank = 2, Row = 0
        #tCK; nop    (0, hi_z);                 // Nop
        #tCK; nop    (0, hi_z);                 // Nop
        #tCK; write  (2, 1024, $random, 0);     // Write : Bank = 2, Col = 0, Dqm = 0, Auto Precharge
        #tCK; nop    (0, $random);              // Nop
        #tCK; nop    (0, $random);              // Nop
        #tCK; nop    (0, $random);              // Nop
        #tCK; nop    (0, hi_z);                 // Nop

        // Write with auto precharge to bank 3 (non-interrupt)
        #tCK; active (3, 0, hi_z);              // Active: Bank = 3, Row = 0
        #tCK; nop    (0, hi_z);                 // Nop
        #tCK; nop    (0, hi_z);                 // Nop
        #tCK; write  (3, 1024, $random, 0);     // Write : Bank = 3, Col = 0, Dqm = 0, Auto precharge
        #tCK; nop    (0, $random);              // Nop
        #tCK; nop    (0, $random);              // Nop
        #tCK; nop    (0, $random);              // Nop
        #tCK; nop    (0, hi_z);                 // Nop

        // Read with auto precharge to bank 0 (non-interrupt)
        #tCK; active (0, 0, hi_z);              // Active: Bank = 0, Row = 0
        #tCK; nop    (0, hi_z);                 // Nop
        #tCK; nop    (0, hi_z);                 // Nop
        #tCK; read   (0, 1024, hi_z, 0);        // Read  : Bank = 0, Col = 0, Dqm = 0, Auto precharge
        #tCK; nop    (0, hi_z);                 // Nop
        #tCK; nop    (0, hi_z);                 // Nop
        #tCK; nop    (0, hi_z);                 // Nop
        #tCK; nop    (0, hi_z);                 // Nop

        // Read with auto precharge to bank 1 (non-interrupt)
        #tCK; active (1, 0, hi_z);              // Active: Bank = 1, Row = 0
        #tCK; nop    (0, hi_z);                 // Nop
        #tCK; nop    (0, hi_z);                 // Nop
        #tCK; read   (1, 1024, hi_z, 0);        // Read  : Bank = 1, Col = 0, Dqm = 0, Auto precharge
        #tCK; nop    (0, hi_z);                 // Nop
        #tCK; nop    (0, hi_z);                 // Nop
        #tCK; nop    (0, hi_z);                 // Nop
        #tCK; nop    (0, hi_z);                 // Nop

        // Read with auto precharge to bank 2 (non-interrupt)
        #tCK; active (2, 0, hi_z);              // Active: Bank = 2, Row = 0
        #tCK; nop    (0, hi_z);                 // Nop
        #tCK; nop    (0, hi_z);                 // Nop
        #tCK; read   (2, 1024, hi_z, 0);        // Read  : Bank = 2, Col = 0, Dqm = 0, Auto precharge
        #tCK; nop    (0, hi_z);                 // Nop
        #tCK; nop    (0, hi_z);                 // Nop
        #tCK; nop    (0, hi_z);                 // Nop
        #tCK; nop    (0, hi_z);                 // Nop

        // Read with auto precharge to bank 3 (non-interrupt)
        #tCK; active (3, 0, hi_z);              // Active: Bank = 3, Row = 0
        #tCK; nop    (0, hi_z);                 // Nop
        #tCK; nop    (0, hi_z);                 // Nop
        #tCK; read   (3, 1024, hi_z, 0);        // Read  : Bank = 3, Col = 0, Dqm = 0, Auto precharge
        #tCK; nop    (0, hi_z);                 // Nop
        #tCK; nop    (0, hi_z);                 // Nop
        #tCK; nop    (0, hi_z);                 // Nop
        #tCK; nop    (0, hi_z);                 // Nop

        #tCK; nop    (0, hi_z);                 // Nop
        #tCK; nop    (0, hi_z);                 // Nop
        #tCK; nop    (0, hi_z);                 // Nop
        #tCK;
    end
$stop;
$finish;
end

endmodule
*/

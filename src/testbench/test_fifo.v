
`timescale 1ns / 1ps

module test_fifo;

    reg         WCLK;
    reg         WRSTn;
    reg         WEN;
    reg  [31:0] WDATA;
    wire        WFULL;
    reg         RCLK;
    reg         RRSTn;
    reg         REN;
    wire [31:0] RDATA;
    wire        REMPTY;

    mfp_fifo_dc 
    #(
        .DATA_WIDTH(32),
        .ADDR_WIDTH(3),
        .USED_SIZE(4)
    )
    fifo
    (
        .WCLK    ( WCLK   ),
        .WRSTn   ( WRSTn  ),
        .WEN     ( WEN    ),
        .WDATA   ( WDATA  ),
        .WFULL   ( WFULL  ),
        .RCLK    ( RCLK   ),
        .RRSTn   ( RRSTn  ),
        .REN     ( REN    ),
        .RDATA   ( RDATA  ),
        .REMPTY  ( REMPTY  )
    );

    parameter tW = 7,
              tR = 20;

    always #(tW/2) WCLK = ~WCLK;
    always #(tR/2) RCLK = ~RCLK;

    initial begin
        WCLK    = 1'b0;
        WRSTn   = 1'b0;
        WEN     = 1'b0;
        WDATA   = 32'b0;
        RCLK    = 1'b0;
        RRSTn   = 1'b0;
        REN     = 1'b0;
    end

    task fifoRead;
        begin
            REN = 1'b1;
            @(posedge RCLK);
            REN = 1'b0;
        end
    endtask

    task fifoWrite;
        input [31:0] iWDATA;
        begin
            WEN     = 1'b1;
            WDATA  = iWDATA;
            @(posedge WCLK);
            WEN     = 1'b0;
        end
    endtask

    always @ (posedge WCLK)
        if(WEN)
            $display("%t WRITEN WDATA=%h", $time, WDATA);

    always @ (posedge RCLK) 
        if(REN)
            #1 $display("%t READEN RDATA=%h", $time, RDATA);

    always @ (posedge WFULL or negedge WFULL)
        $display("%t WFULL=%h", $time, WFULL);

    always @ (posedge REMPTY or negedge REMPTY)
        $display("%t REMPTY=%h", $time, REMPTY);
   
    initial begin
        fork
            begin
                WRSTn = 0;
                @(posedge WCLK);
                @(posedge WCLK);
                WRSTn = 1;

                fifoWrite ( 32'hAAAABBBB );
                fifoWrite ( 32'hBBBBCCCC );
                fifoWrite ( 32'hCCCCDDDD );
                fifoWrite ( 32'hCCCCEEEE );

                repeat (20) @(posedge WCLK);
            end

            begin
                RRSTn = 0;
                @(posedge RCLK);
                @(posedge RCLK);
                RRSTn = 1;

                @(negedge REMPTY);
                @(posedge RCLK);
                fifoRead();

                repeat (20) @(posedge RCLK);
            end
        join
        $stop;
    end

endmodule

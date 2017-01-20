



module ahb_lite_rw_master
#(
    parameter   DELAY_BITS  = 12,
                MAX_HADDR   = 128
)
(
    //ABB-Lite master side
    input                               HCLK,    
    input                               HRESETn,
    output  reg [ 31 : 0 ]              HADDR,
    output      [  2 : 0 ]              HBURST,
    output                              HSEL,
    output      [  2 : 0 ]              HSIZE,
    output  reg [  1 : 0 ]              HTRANS,
    output      [ 31 : 0 ]              HWDATA,
    output  reg                         HWRITE,
    input   reg [ 31 : 0 ]              HRDATA,
    input                               HREADY,
    input                               HRESP,

    //debug side
    output  reg [ 31 : 0 ]              ERRCOUNT
);
    assign HBURST   = 3'b0;     //single burst
    assign HSEL     = 1'b1;     //select 
    assign HSIZE    = 3'b010;   //32 bit transfer

    reg         [ 31 : 0 ]              HADDR_old;
    reg     [ DELAY_BITS - 1 : 0 ]  delay_u;
    wire    BigDelayFinished    = ~|delay_u;

    wire    [ 31 : 0 ]  debugValue = HADDR_old;

    assign HWDATA = debugValue;

    reg     [  3 : 0 ]              State;

    always @(posedge HCLK) begin
        if(!HRESETn)
            State <= 0;
        else 
            case(State)
                //init
                0:  begin
                        HADDR_old   <= 0;
                        HADDR       <= 0;
                        HTRANS      <= 2'b10;   //NONSEQ
                        HWRITE      <= 1'b1;
                        State       <= 1;
                        ERRCOUNT    <= 0;
                    end
                
                //write
                1:  if(HREADY) begin
                        if(HADDR == MAX_HADDR)
                            State   <= 3;
                        else begin
                            HADDR_old   <= HADDR;
                            HADDR       <= HADDR + 4;
                        end
                    end

                //wait
                3:  begin
                        HWRITE      <= 1'b0;
                        HTRANS      <= 2'b00;   //IDLE
                        delay_u     <= 0;
                        State       <= 4;
                    end

                4:  begin
                        delay_u     <= delay_u + 1;
                        if( &delay_u )
                             State  <= 5;
                    end

                //read and check
                5:  begin
                        HADDR       <= 0;
                        HTRANS      <= 2'b10;   //NONSEQ
                        State       <= 6;
                    end

                6:  begin
                        State       <= 7;
                    end

                7:  if(HREADY) begin
                        if(HRDATA != debugValue)
                            ERRCOUNT <= ERRCOUNT + 1;
                        
                        if(HADDR == MAX_HADDR)
                            State   <= 8;
                        else begin
                            HADDR_old   <= HADDR;
                            HADDR       <= HADDR + 4;
                            State       <= 7;
                        end
                    end

                8:  HTRANS      <= 2'b00;   //IDLE;

            endcase
    end
endmodule
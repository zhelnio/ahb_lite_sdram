/* Simple SDRAM controller for MIPSfpga+ system AHB-Lite bus
 * Copyright(c) 2016 Stanislav Zhelnio
 * https://github.com/zhelnio/ahb_lite_sdram
 */

//  AHB-Lite master for SDRAM controller HW test
module ahb_lite_rw_master
#(
    parameter   ADDR_INCREMENT  = 32'h10004,    /* will be added to addr after every iteration */
                DELAY_BITS      = 10,           /* determine delay before every read cycle */
                INCREMENT_CNT   = 8,            /* addr increment operations count*/
                READ_ITER_CNT   = 2,            /* WAIT-and-READ cycles count*/
                MAX_HADDR       = INCREMENT_CNT * ADDR_INCREMENT 
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
    input       [ 31 : 0 ]              HRDATA,
    input                               HREADY,
    input                               HRESP,

    //debug side
    output  reg [ 31 : 0 ]              ERRCOUNT,   /* errors count */
    output  reg [  7 : 0 ]              CHKCOUNT,   /* current check iteration num */
    output                              S_WRITE,    /* doing WRITE */
    output                              S_CHECK,    /* doing WAIT-and-READ iterations */
    output                              S_SUCCESS,  /* all checks PASS */
    output                              S_FAILED,   /* all checks FAILED */
    input       [ 31 : 0 ]              STARTADDR   /* start address (set before reset) */
);
    assign HBURST   = 3'b0;     //single burst
    assign HSEL     = 1'b1;     //select 
    assign HSIZE    = 3'b010;   //32 bit transfer

    reg     [ 31 : 0 ]              HADDR_old;
    reg     [ DELAY_BITS - 1 : 0 ]  delay_u;
    wire    BigDelayFinished    = ~|delay_u;

    wire    [ 31 : 0 ]  debugValue = HADDR_old;

    assign HWDATA = debugValue;

    reg     [  3 : 0 ] status;
    assign  { S_WRITE, S_CHECK, S_SUCCESS, S_FAILED } = status;

    reg     [  3 : 0 ]              State;

    always @(posedge HCLK) begin
        if(!HRESETn)
            State <= 0;
        else 
            case(State)
                //init
                0:  begin
                        HADDR_old   <= STARTADDR;
                        HADDR       <= STARTADDR;
                        HTRANS      <= 2'b10;   //NONSEQ
                        HWRITE      <= 1'b1;
                        State       <= 1;
                        ERRCOUNT    <= 0;
                        status      <= 4'b1000;
                        CHKCOUNT    <= 0;
                    end
                
                //write
                1:  if(HREADY) begin
                        if(HADDR == MAX_HADDR + STARTADDR)
                            State   <= 3;
                        else begin
                            HADDR_old   <= HADDR;
                            HADDR       <= HADDR + ADDR_INCREMENT;
                        end
                    end

                //wait
                3:  begin
                        HWRITE      <= 1'b0;
                        HTRANS      <= 2'b00;   //IDLE
                        delay_u     <= 0;
                        State       <= 4;
                        status      <= 4'b0100;
                    end

                4:  begin
                        delay_u     <= delay_u + 1;
                        if( &delay_u )
                             State  <= 5;
                    end

                //read and check
                5:  begin
                        HADDR       <= STARTADDR;
                        HTRANS      <= 2'b10;   //NONSEQ
                        State       <= 6;
                    end

                6:  begin
                        HADDR_old   <= HADDR;
                        State       <= 7;
                    end

                7:  if(HREADY) begin
                        if(HRDATA != debugValue)
                            ERRCOUNT <= ERRCOUNT + 1; 
                        
                        if(HADDR == MAX_HADDR + STARTADDR) begin

                            if ( CHKCOUNT == READ_ITER_CNT ) begin
                                HTRANS      <= 2'b00;
                                State       <= ( |ERRCOUNT ) ? 8 : 9;
                                end
                            else begin
                                State       <= 3;
                                CHKCOUNT    <= CHKCOUNT + 1;
                            end
                        end
                        
                        else begin
                            HADDR_old   <= HADDR;
                            HADDR       <= HADDR + ADDR_INCREMENT;
                        end
                    end

                8:  status      <= 4'b0001; //FAILED
                9:  status      <= 4'b0010; //SUCCESS

            endcase
    end
endmodule
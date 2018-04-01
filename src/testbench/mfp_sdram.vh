


`define SDRAM_ADDR_BITS     13       /* SDRAM Address input size */
`define SDRAM_ROW_BITS      13       /* SDRAM Row address size */
`define SDRAM_COL_BITS      10       /* SDRAM Column address size */
`define SDRAM_DQ_BITS       16       /* SDRAM Data i/o size, only x16 supported */
`define SDRAM_DM_BITS       2        /* SDRAM Data i/o mask size, only x2 supported */
`define SDRAM_BA_BITS       2        /* SDRAM Bank address size */
`define SDRAM_SADDR_BITS    (`SDRAM_ROW_BITS + `SDRAM_COL_BITS + `SDRAM_BA_BITS)

// delay params depends on Datasheet values, frequency and FSM states count
// default values are calculated for simulation(!): Micron SDRAM Verilog model with fclk=50 MHz and CAS=2 
`define SDRAM_DELAY_nCKE          20        /* Init delay before bringing CKE high 
                                            >= (T * fclk) where T    - CKE LOW init timeout 
                                                            fclk - clock frequency  */
`define SDRAM_DELAY_tREF          4000      /* Refresh period 
                                            <= ((tREF - tRC) * fclk / RowsInBankCount)  */
`define SDRAM_DELAY_tRP           1         /* PRECHARGE command period 
                                            >= (tRP * fclk - 1)                         */
`define SDRAM_DELAY_tRFC          7         /* AUTO_REFRESH period 
                                            >= (tRFC * fclk - 2)                        */
`define SDRAM_DELAY_tMRD          2         /* LOAD_MODE_REGISTER to ACTIVE or REFRESH command 
                                            >= (tMRD * fclk - 2)                        */
`define SDRAM_DELAY_tRCD          0         /* ACTIVE-to-READ or WRITE delay 
                                            >= (tRCD * fclk - 1)                        */
`define SDRAM_DELAY_tCAS          2         /* CAS delay, also depends on clock phase shift 
                                            =  (CAS)                                */
`define SDRAM_DELAY_afterREAD     3         /* depends on tRC for READ with auto precharge command 
                                            >= ((tRC - tRCD) * fclk - 1 - CAS)          */
`define SDRAM_DELAY_afterWRITE    4         /* depends on tRC for WRITE with auto precharge command 
                                            >= ((tRC - tRCD) * fclk - 1)                */
`define SDRAM_COUNT_initAutoRef   2         /* count of AUTO_REFRESH during Init operation */


`define SDRAM_CMD_FIFO_DATA_WIDTH   36
`define SDRAM_CMD_FIFO_USED_SIZE    2
`define SDRAM_CMD_FIFO_ADDR_WIDTH   2
`define SDRAM_DATA_FIFO_USED_SIZE   2
`define SDRAM_DATA_FIFO_ADDR_WIDTH  2
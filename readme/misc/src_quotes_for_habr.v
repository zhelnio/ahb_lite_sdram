
// This file contains some source fragments of Simple SDRAM (mfp_ahb_ram_sdram.v)
// It is used in this article: https://habrahabr.ru/post/321532/

/*
Состояния конечного автомата, описывающие процедуру чтения, полностью соответствуют тому, 
что было описано выше на примере диаграммы READ With Auto Precharge:
*/

/* 082 */ 
/* 083 */                 S_READ0_ACT         = 20,   /* Doing ACTIVE */
/* 084 */                 S_READ1_NOP         = 21,   /* Waiting for DELAY_tRCD after ACTIVE */
/* 085 */                 S_READ2_READ        = 22,   /* Doing READ with Auto precharge */
/* 086 */                 S_READ3_NOP         = 23,   /* Waiting for DELAY_tCAS after READ */
/* 087 */                 S_READ4_RD0         = 24,   /* Reading 1st word */
/* 088 */                 S_READ5_RD1         = 25,   /* Reading 2nd word */
/* 089 */                 S_READ6_NOP         = 26,   /* Waiting for DELAY_afterREAD - it depends on tRC */
/* 090 */ 

/*
Правила перехода между этими состояниями:
*/

/* 133 */     always @ (*) begin
/* 134 */ 
/* 135 */         //State change decision
/* 136 */         case(State)
/* 137 */             S_IDLE              :   Next = NeedAction ? (HWRITE ? S_WRITE0_ACT : S_READ0_ACT) 
/* 138 */                                                       : (NeedRefresh ? S_AREF0_AUTOREF : S_IDLE);  

/* 155 */             S_READ0_ACT         :   Next = (DELAY_tRCD == 0) ? S_READ2_READ : S_READ1_NOP;
/* 156 */             S_READ1_NOP         :   Next = DelayFinished ? S_READ2_READ : S_READ1_NOP;
/* 157 */             S_READ2_READ        :   Next = (DELAY_tCAS == 0) ? S_READ4_RD0 : S_READ3_NOP;
/* 158 */             S_READ3_NOP         :   Next = DelayFinished ? S_READ4_RD0 : S_READ3_NOP;
/* 159 */             S_READ4_RD0         :   Next = S_READ5_RD1;
/* 160 */             S_READ5_RD1         :   Next = (DELAY_afterREAD != 0) ? S_READ6_NOP : (
/* 161 */                                            NeedRefresh  ? S_AREF0_AUTOREF : S_IDLE );
/* 162 */             S_READ6_NOP         :   Next = ~DelayFinished ? S_READ6_NOP : (
/* 163 */                                            NeedRefresh  ? S_AREF0_AUTOREF : S_IDLE );
/* 164 */ 

/* 175 */         endcase
/* 176 */     end

/*
Там, где необходима задержка, она заносится в регистр delay_n, нулевое значение 
регистра соответствует флагу DelayFinished. На статусах S_READ4_RD0 и S_READ4_RD1 
производится считывание данных из шины DQ:
*/

/* 178 */     always @ (posedge HCLK) begin
/* 179 */         
/* 180 */         //short delay and count operations
/* 181 */         case(State)

/* 187 */             S_READ2_READ        :   delay_n <= DELAY_tCAS       - 1;
/* 188 */             S_READ5_RD1         :   delay_n <= DELAY_afterREAD  - 1;

/* 192 */             default             :   if (|delay_n) delay_n <= delay_n - 1;
/* 193 */         endcase

/* 203 */         //data and addr operations
/* 204 */         case(State)

/* 214 */             S_READ4_RD0         :   DATA [15:0] <= DQ;
/* 215 */             S_READ5_RD1         :   HRDATA <= { DQ, DATA [15:0] };

/* 217 */             default             :   ;
/* 218 */         endcase
/* 219 */     end

/*
Кодирование команд и их вывод в зависимости от текущего состояния:
*/

/* 221 */     // SADDR = { BANKS, ROWS, COLUMNS }
/* 222 */     wire  [COL_BITS - 1 : 0]  AddrColumn  = SADDR_old [ COL_BITS - 1 : 0 ];
/* 223 */     wire  [ROW_BITS - 1 : 0]  AddrRow     = SADDR_old [ ROW_BITS + COL_BITS - 1 : COL_BITS ];
/* 224 */     wire  [BA_BITS  - 1 : 0]  AddrBank    = SADDR_old [ SADDR_BITS - 1 : ROW_BITS + COL_BITS ];
/* 225 */ 
/* 226 */     reg    [ 4 : 0 ]    cmd;
/* 227 */     assign  { CKE, CSn, RASn, CASn, WEn } = cmd;
/* 228 */ 
/* 229 */     parameter   CMD_NOP_NCKE        = 5'b00111,
/* 230 */                 CMD_NOP             = 5'b10111,
/* 231 */                 CMD_PRECHARGEALL    = 5'b10010,
/* 232 */                 CMD_AUTOREFRESH     = 5'b10001,
/* 233 */                 CMD_LOADMODEREG     = 5'b10000,
/* 234 */                 CMD_ACTIVE          = 5'b10011,
/* 235 */                 CMD_READ            = 5'b10101,
/* 236 */                 CMD_WRITE           = 5'b10100;

/* 248 */     // set SDRAM i/o
/* 249 */     assign DQM = { DM_BITS { 1'b0 }};
/* 250 */ 
/* 251 */     always @ (*) begin
/* 252 */         case(State)
/* 253 */             default             :   cmd = CMD_NOP;

/* 260 */             S_READ0_ACT         :   begin cmd =   CMD_ACTIVE;         
                                                    ADDR =  AddrRow;     
                                                    BA =    AddrBank; 
                                                    end

/* 261 */             S_READ2_READ        :   begin cmd = CMD_READ;           
                                                    ADDR = AddrColumn | SDRAM_AUTOPRCH_FLAG;  
                                                    BA =  AddrBank; 
                                                    end
/* 267 */         endcase
/* 274 */     end

/*
Все задержки являются настраиваемыми и задаются в параметрах модуля, что должно 
упростить портирование на другие платы, а также модификацию настроек в случае 
изменения частоты тактового сигнала.
*/

/* 005 */ module mfp_ahb_ram_sdram
/* 006 */ #(
/* 007 */     parameter   ADDR_BITS           = 13,       /* SDRAM Address input size */
/* 008 */                 ROW_BITS            = 13,       /* SDRAM Row address size */
/* 009 */                 COL_BITS            = 10,       /* SDRAM Column address size */
/* 010 */                 DQ_BITS             = 16,       /* SDRAM Data i/o size, only x16 supported */
/* 011 */                 DM_BITS             = 2,        /* SDRAM Data i/o mask size */
/* 012 */                 BA_BITS             = 2,        /* SDRAM Bank address size */
/* 013 */                 SADDR_BITS          = (ROW_BITS + COL_BITS + BA_BITS),
/* 014 */ 
/* 015 */     // delay params depends on Datasheet values, frequency and FSM states count
/* 016 */     // default values are calculated for simulation(!): Micron SDRAM Verilog model with fclk=50 MHz and CAS=2 
/* 017 */     parameter   DELAY_nCKE          = 20,       /* Init delay before bringing CKE high 
/* 018 */                                                    >= (T * fclk) where T    - CKE LOW init timeout 
/* 019 */                                                                        fclk - clock frequency  */
/* 020 */                 DELAY_tREF          = 390,      /* Refresh period 
/* 021 */                                                    <= ((tREF - tRC) * fclk / RowsInBankCount)  */
/* 022 */                 DELAY_tRP           = 0,        /* PRECHARGE command period 
/* 023 */                                                    >= (tRP * fclk - 1)                         */
/* 024 */                 DELAY_tRFC          = 2,        /* AUTO_REFRESH period 
/* 025 */                                                    >= (tRFC * fclk - 2)                        */
/* 026 */                 DELAY_tMRD          = 0,        /* LOAD_MODE_REGISTER to ACTIVE or REFRESH command 
/* 027 */                                                    >= (tMRD * fclk - 2)                        */
/* 028 */                 DELAY_tRCD          = 0,        /* ACTIVE-to-READ or WRITE delay 
/* 029 */                                                    >= (tRCD * fclk - 1)                        */
/* 030 */                 DELAY_tCAS          = 0,        /* CAS delay, also depends on clock phase shift 
/* 031 */                                                    =  (CAS - 1)                                */
/* 032 */                 DELAY_afterREAD     = 0,        /* depends on tRC for READ with auto precharge command 
/* 033 */                                                    >= ((tRC - tRCD) * fclk - 1 - CAS)          */
/* 034 */                 DELAY_afterWRITE    = 2,        /* depends on tRC for WRITE with auto precharge command 
/* 035 */                                                    >= ((tRC - tRCD) * fclk - 1)                */
/* 036 */                 COUNT_initAutoRef   = 2         /* count of AUTO_REFRESH during Init operation */
/* 037 */ )

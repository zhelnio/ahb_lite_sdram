
set_time_format -unit ns -decimal_places 3

##### Create Clock
create_clock -period "50.0 MHz" [get_ports CLOCK_50]
create_clock -period "50.0 MHz" [get_ports CLOCK2_50]
create_clock -period "50.0 MHz" [get_ports CLOCK3_50]
create_clock -period "50.0 MHz" [get_ports CLOCK4_50]

##### Create Generated Clock
derive_pll_clocks
set sdram_clk  pll|pll_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk
set cpu_clk    pll|pll_inst|altera_pll_i|general[1].gpll~PLL_OUTPUT_COUNTER|divclk
create_generated_clock -name sdram_oclk -source $sdram_clk [get_ports {DRAM_CLK}]

##### Set Clock Latency
##### Set Clock Uncertainty
derive_clock_uncertainty

##### Set Input Delay
set_input_delay -clock sdram_oclk -min 3 [get_ports DRAM_DQ*]
set_input_delay -clock sdram_oclk -max 6 [get_ports DRAM_DQ*]

##### Set Output Delay
set sdram_outs {DRAM_CKE DRAM_LDQM DRAM_UDQM DRAM_RAS_N DRAM_WE_N DRAM_CS_N DRAM_CAS_N DRAM_BA[*] DRAM_ADDR[*] DRAM_DQ[*]}
set_output_delay -clock sdram_oclk -min -0.8 [get_ports $sdram_outs]
set_output_delay -clock sdram_oclk -max 1.5 [get_ports $sdram_outs]

##### Set Clock Groups
##### Set False Path
set_false_path -from * -to [get_ports {LEDR*}]
set_false_path -from * -to [get_ports {HEX*}]
set_false_path -from [get_ports {KEY*}] -to [all_clocks]
set_false_path -from [get_ports {SW*}] -to [all_clocks]

##### Set Multicycle Path
set_multicycle_path -from [get_clocks {sdram_oclk}] -to $cpu_clk -setup -end 2

##### Set Maximum Delay
##### Set Minimum Delay
##### Set Input Transition
##### Set Load

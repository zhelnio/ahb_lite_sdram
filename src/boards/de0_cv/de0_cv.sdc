

set sdram_outs {DRAM_CKE DRAM_LDQM DRAM_UDQM DRAM_RAS_N DRAM_WE_N DRAM_CS_N DRAM_CAS_N DRAM_BA[*] DRAM_ADDR[*] DRAM_DQ[*]}

set_time_format -unit ns -decimal_places 3

create_clock -period "50.0 MHz" [get_ports CLOCK_50] -name clk_ext
create_clock -period "50.0 MHz" [get_ports CLOCK2_50]
create_clock -period "50.0 MHz" [get_ports CLOCK3_50]
create_clock -period "50.0 MHz" [get_ports CLOCK4_50]

create_generated_clock -source {pll|pll_inst|altera_pll_i|general[0].gpll~FRACTIONAL_PLL|refclkin} -multiply_by 20 -divide_by 2 -duty_cycle 50.00 -name clk -master_clock {clk_ext} {pll|pll_inst|altera_pll_i|general[0].gpll~FRACTIONAL_PLL|vcoph[0]}

create_generated_clock -source {pll|pll_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|vco0ph[0]} -divide_by 10 -phase -72.00 -duty_cycle 50.00 -name sdram_clk {pll|pll_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}

create_generated_clock -source {pll|pll_inst|altera_pll_i|general[1].gpll~PLL_OUTPUT_COUNTER|vco0ph[0]} -divide_by 10 -duty_cycle 50.00 -name cpu_clk {pll|pll_inst|altera_pll_i|general[1].gpll~PLL_OUTPUT_COUNTER|divclk}

create_generated_clock -name sdram_oclk -source [get_pins {pll|pll_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}] [get_ports {DRAM_CLK}]

derive_clock_uncertainty

set_input_delay -clock sdram_oclk -min 3 [get_ports DRAM_DQ*]
set_input_delay -clock sdram_oclk -max 6 [get_ports DRAM_DQ*]

set_output_delay -clock sdram_oclk -min -0.8 [get_ports $sdram_outs]
set_output_delay -clock sdram_oclk -max 1.5 [get_ports $sdram_outs]

set_multicycle_path -from [get_clocks {sdram_oclk}] -to [get_clocks {cpu_clk}] -setup -end 2

set_false_path -from * -to [get_ports {LEDR*}]
set_false_path -from * -to [get_ports {HEX*}]
set_false_path -from [get_ports {KEY*}] -to [all_clocks]
set_false_path -from [get_ports {SW*}] -to [all_clocks]

# derive_pll_clocks


create_clock -period "50.0 MHz" [get_ports CLOCK_50]
create_clock -period "50.0 MHz" [get_ports CLOCK2_50]
create_clock -period "50.0 MHz" [get_ports CLOCK3_50]
create_clock -period "50.0 MHz" [get_ports CLOCK4_50]

derive_pll_clocks
derive_clock_uncertainty

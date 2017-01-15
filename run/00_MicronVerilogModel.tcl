
vlib work

set a0 -vlog01compat
set a1 +define+den512Mb
set a2 +define+sg75
set a3 +define+x16
set a4 +define+SIMULATION
set a5 +incdir+../../src/testbench/sdr_sdram/*.vh
set a6 ../../src/testbench/sdr_sdram/*.v

vlog $a0 $a1 $a2 $a3 $a4 $a5 $a6

vsim work.test
add wave -radix hex sim:/test/*
run -all

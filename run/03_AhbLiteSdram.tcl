
vlib work

set a0 -vlog01compat
set a1 +define+den512Mb
set a2 +define+sg75
set a3 +define+x16
set a4 +define+SIMULATION

set a5 +incdir+../../src/testbench/sdr_sdram
set a6 +incdir+../../src/ahb_lite_sdram
# set a6 +incdir+../../src/testbench/sdr_sdram/sdr_parameters.vh
set a7 +incdir+../../src/testbench/sdr_sdram/sdv.v
set a8 ../../src/testbench/sdr_sdram/*.v
set a10 ../../src/ahb_lite_sdram/*.v
# set a8 ../../src/testbench/sdr_sdram/sdv.v
set a9 ../../src/testbench/test_ahb_lite_sdram.v

vlog $a0 $a1 $a2 $a3 $a4 $a5 $a6 $a7 $a8 $a10 $a9
#  

vsim work.test_ahb_lite_sdram
add wave -radix hex sim:/test_ahb_lite_sdram/*
add wave -radix unsigned sim:/test_ahb_lite_sdram/mem/State
run -all
wave zoom full
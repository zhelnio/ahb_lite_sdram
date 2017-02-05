# ahb_lite_sdram
Simple SDRAM controller for MIPSfpga+ system AHB-Lite bus.

TODO:
- [x] standalone work in simulator
- [x] standalone work on hardware (Terasic de10-lite board)
- [x] work as a part of MIPSfpga+ [in simulator] (https://github.com/zhelnio/mipsfpga-plus/tree/de10_lite)
- [x] work as a part of MIPSfpga+ [on hardware] (https://github.com/zhelnio/mipsfpga-plus/tree/de10_lite) (Terasic de10-lite board)
- [ ] merging to MIPSfpga+ repository

Main features:
- small (~300 rows of code);
- easy tunable (all time constraints are coded as module params);
- simple  (no clock domain crossing);
- supports x16 sdram only;
- only init, read, write and auto-refresh operations;
- page burst access is not supported;
- clock suspend mode is not supported;
- only HSIZE4 (x32) AHB-Lite data transfer operations supported
- Micron Technology, Inc. ("MTI") SDRAM Verilog model (v2.3) is used for simulation

[MIPSfpga+ / mipsfpga-plus / MFP] (https://github.com/MIPSfpga/mipsfpga-plus) is a cleaned-up and improved variant of MIPSfpga-based system.

![Alt text](/readme/simulation_log.png?raw=true "log")

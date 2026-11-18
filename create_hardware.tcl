set root [file dirname [file normalize [info script]]]
set_param board.repoPaths [list D:/Xilinx/Vivado/2026.1/data/boards/board_files]
create_project arty_z7_hello "$root/hardware" -part xc7z020clg400-1
set_property board_part digilentinc.com:arty-z7-20:part0:1.1 [current_project]
create_bd_design system
create_bd_cell -type ip -vlnv xilinx.com:ip:processing_system7:5.5 processing_system7_0
apply_bd_automation -rule xilinx.com:bd_rule:processing_system7 -config {make_external "FIXED_IO, DDR" apply_board_preset "1" Master "Disable" Slave "Disable"} [get_bd_cells processing_system7_0]
set_property -dict [list CONFIG.PCW_UART0_PERIPHERAL_ENABLE {1} CONFIG.PCW_UART0_UART0_IO {MIO 14 .. 15} CONFIG.PCW_UART0_BAUD_RATE {115200} CONFIG.PCW_USE_M_AXI_GP0 {0} CONFIG.PCW_EN_CLK0_PORT {0} CONFIG.PCW_EN_RST0_PORT {0}] [get_bd_cells processing_system7_0]
validate_bd_design
save_bd_design
generate_target all [get_files system.bd]
make_wrapper -files [get_files system.bd] -top -import
update_compile_order -fileset sources_1
write_hw_platform -fixed -force -file "$root/arty_z7_hello.xsa"
close_project

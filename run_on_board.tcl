# Run with XSDB only after connecting and powering the Arty Z7-20.
# Resets the selected Zynq processor system; does not write flash or SD.
set root [file dirname [file normalize [info script]]]
set elf "$root/software_jtag/hello_world/build/hello_world.elf"
if {![file exists $elf]} {error "Build hello_world first; ELF not found at $elf"}
connect
targets -set -filter {name =~ "*Cortex-A9*#0"}
rst -system
after 3000
source "$root/hardware/arty_z7_hello.gen/sources_1/bd/system/ip/system_processing_system7_0_0/ps7_init.tcl"
ps7_init
ps7_post_config
dow $elf
con

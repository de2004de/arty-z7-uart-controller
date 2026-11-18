# Arty Z7-20 UART Controller

The current Vivado project is in `hardware/arty_z7_hello.xpr`. It includes the custom UART logic and its simulation testbenches. The matching C application is in `vitis_workspace/hello_world/src`. See [the UART guide](Arty_Z7_UART_Guide.md) for the block design, software interface, and build procedure.

The earlier processor-only example uses `software_jtag` and `arty_z7_hello.xsa`. Its reproduction scripts create that earlier design; run them in a separate directory. For the custom design, open the saved Vivado project instead. When using a different checkout location, point Vitis to the appropriate local XSA, regenerate the platform and rebuild the application. Install the Digilent Arty Z7-20 board definition in Vivado.

## Original processor-only example

Separate project for Vivado / Vitis 2026.1. The original UART_VHDL project is untouched.

## Design

- Zynq-7020 processing system, ARM Cortex-A9 core 0.
- Digilent Arty Z7-20 board preset (local board definition version 1.1).
- UART0 RX on MIO14 and TX on MIO15, connected to onboard micro-USB JTAG/UART J14.
- Standalone C Hello World application; standard input/output use ps7_uart_0.
- HTerm: 115200 baud, 8 data bits, no parity, 1 stop bit, no flow control.
- This example does not use the custom VHDL TX/RX modules or require a PL bitstream.

## Files and opening

- Vivado project: `hardware/arty_z7_hello.xpr`.
- Hardware export: `arty_z7_hello.xsa`.
- Vitis workspace: `software_jtag`.
- Reproduction scripts: `create_hardware.tcl` and `create_software.py` (use a fresh project directory to rerun).

## Board test

1. Connect a data-capable micro-USB cable to J14 and power the board appropriately.
2. For a clean JTAG test, set JP4 to the board's JTAG boot position while powered off, then power on.
3. In HTerm select the board's USB serial COM port and the settings above; connect before running the application so its initial message is captured. Do not open that COM port in another terminal simultaneously.
4. Open the `software_jtag` workspace in Vitis. Run/debug `hello_world` on Cortex-A9 core 0 using JTAG, with processing-system initialization enabled. Use the exported PS initialization to initialize clocks, DDR, and MIO. No PL bitstream download is needed for this PS-only example; no boot-image component is generated.
5. HTerm should receive the application's Hello World text. If you connected HTerm late, rerun the application.

Seeing a COM port only proves the PC recognizes the USB bridge. Text requires software executing on the board. JTAG loading is temporary; power cycling requires reloading unless a boot image has been installed separately. This project does not program flash or an SD card.

## Validation notes

The hardware export, standalone ARM platform, and Hello World C executable built successfully with Vivado/Vitis 2026.1. Executable: `software_jtag/hello_world/build/hello_world.elf`.

`run_on_board.tcl` is an untested XSDB launch script for the connected board. It resets the processor system, applies `ps7_init`, downloads the executable, and runs it. Open HTerm before executing it. The earlier `software` directory is an incomplete failed build attempt; use `software_jtag`.

Hardware validation completed. The board preset produces Vivado warnings PSU-1 and PSU-2 about negative DDR DQS-to-clock delay values on lanes 2 and 3. Preset values were preserved; actual DDR operation requires board testing.

The board was disconnected during preparation. HTerm reception and execution on hardware have not been verified.

## References

- https://www.farnell.com/datasheets/4514628.pdf (Digilent board reference manual)
- https://docs.amd.com/r/en-US/ug1165-zynq-embedded-design-tutorial/Running-the-Hello-World-Application-on-a-ZC702-Board (PS-only execution principle; board settings here are Arty-specific)

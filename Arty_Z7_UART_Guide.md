# Arty Z7-20 UART Loopback

## 1. Purpose and scope

**Hardware and software reference · Revision 1 · 17 November 2026**

This project lets an ARM program test a UART that you designed in VHDL. You type a character in HTerm. The ARM receives it through the board's PS UART0, asks your FPGA transmitter to serialize it, retrieves the byte reconstructed by your FPGA receiver, checks it, and sends it back to HTerm.

The project has progressed from Hello World, through software-controlled LEDs, to a working hardware/software UART loopback. The current application echoes characters after checking that they passed through the custom UART correctly. Uppercase `Q` exits the application.

This guide documents the saved project in `.`, inspected on the date above. Hardware behavior comes from the VHDL, block design, constraints, and routed timing report. Software behavior comes from the current `helloworld.c` and platform/launch configuration. Board-test results are the outputs you reported; this documentation task did not rerun or reprogram the board.

**Reading order:** Sections 2–4 explain the system. Sections 5–9 explain its implementation. Sections 10–12 explain rebuilding and testing. Sections 13–15 cover troubleshooting and future changes. The source index and file fingerprint manifest help you find the exact files.

## 2. The complete data path

```text
PC / HTerm                         Arty Z7-20
                                  ┌──────────────────────────────┐
     character ── USB serial ───► │ PS UART0 RX                   │
                                  │    ↓ inbyte()                 │
                                  │ ARM Cortex-A9 program         │
                                  │    ↓ AXI GPIO channel 1       │
                                  │ command + 8-bit parallel data │
                                  │    ↓ command pulse            │
                                  │ VHDL TX ── serial ──► VHDL RX │
                                  │                         ↓    │
                                  │                    RX FIFO   │
                                  │                         ↓    │
                                  │ AXI GPIO channel 2 → ARM     │
      echo ◄─── USB serial ────── │ PS UART0 TX ← outbyte()       │
                                  └──────────────────────────────┘
```

The ARM is an active participant: it reads a byte, writes commands, polls status, compares results, and echoes the result. PS UART0 RX is not wired straight into the VHDL transmitter. The bridge between software and your HDL is a parallel memory-mapped GPIO interface.

### Two different UARTs

| Property | PS UART0 | Your PL UART |
| --- | --- | --- |
| Implementation | Built into the Zynq processing system | VHDL synthesized into FPGA logic |
| Purpose here | PC communication | Test your TX, RX, FIFO, and command interface |
| Rate | 115200 baud | Approximately 9600 baud |
| Frame | 8 data bits, no parity, 1 stop bit | 8 data bits, no parity, 1 stop bit |
| Connection | UART0 on MIO14–15; board USB/UART connection | TX connected to RX inside the FPGA |
| Software access | `inbyte()` / `outbyte()` through BSP standard I/O | `XGpio_DiscreteWrite()` / `XGpio_DiscreteRead()` |

The two baud rates do not have to match. Software transfers complete bytes between two separate serial links. It does, however, have to respect the slower link's throughput.

### PS, PL, and the processor

**PS** means Processing System: the ARM Cortex-A9 processor and built-in peripherals. **PL** means Programmable Logic: the FPGA fabric that implements your VHDL and the AXI IP blocks.

This project runs on the existing Zynq ARM processor, `ps7_cortexa9_0`. It does not use MicroBlaze. The C application runs in a standalone domain rather than under Linux.

The board's USB host connector is not interchangeable with its USB JTAG/UART connection. Use the micro-USB JTAG/UART connection used in the successful tests. A detected COM port proves that the PC sees the USB serial interface; it does not prove that your ARM program or your custom FPGA circuit is running.

## 3. Project organization and build artifacts

### Active locations

| Item | Current location |
| --- | --- |
| Project root | `.` |
| Vivado project | `./hardware/arty_z7_hello.xpr` |
| Block design | `./hardware/arty_z7_hello.srcs/sources_1/bd/system/system.bd` |
| Exported hardware used by platform | `./system_wrapper.xsa` |
| Active Vitis workspace | `./vitis_workspace` |
| Platform component | `arty_uart0_platform` |
| Application component | `hello_world` |
| Standalone domain | `standalone_ps7_cortexa9_0` |
| Application source | `./vitis_workspace/hello_world/src/helloworld.c` |
| Application executable | `./vitis_workspace/hello_world/build/hello_world.elf` |

Open `vitis_workspace` itself in Vitis. The project also contains an older `software_jtag` workspace with similarly named components. Opening the parent directory can expose duplicate `hello_world` and platform entries, such as `(1)` and `(2)`. Check the component's filesystem path instead of relying on the displayed suffix.

The current platform references the XSA in the project root. Do not assume an older export in `hardware/` or the older `arty_z7_hello.xsa` is current.

### What each generated file does

| File or component | Meaning |
| --- | --- |
| VHDL sources | Describe hardware registers, wires, state machines, and memory behavior |
| `system.bd` | Describes the connected PS, AXI IP, GPIO, and custom module |
| `system_wrapper` | Generated HDL top-level wrapper around the block design |
| `.xdc` | Physical pin and electrical/timing constraints |
| `.bit` | Configures the PL hardware |
| `.xsa` | Hardware handoff to Vitis, including hardware description and the bitstream when exported with it |
| Platform / BSP | Supplies hardware definitions, startup support, and drivers for the application |
| `.elf` | Compiled ARM program loaded into target memory |
| PS initialization Tcl | Initializes the processing system for the configured hardware |

The current synthesis top is `system_wrapper`. Vivado manages the active wrapper under the generated `.gen` tree. An older imported wrapper also exists; do not edit a generated wrapper to change the design. Edit the block design or source module and regenerate.

The original `UART_VHDL` project is the origin of the UART modules. The working integration uses its own imported copies. Editing the original project does not automatically update those copies.

## 4. Vivado block design

### Blocks and their jobs

| Block | Function in this design |
| --- | --- |
| `processing_system7_0` | ARM system, PS UART0, DDR interface, AXI master, PL clock and reset sources |
| `axi_smc` | AXI SmartConnect; routes one PS master interface to the two GPIO peripherals |
| `axi_gpio_0` | Earlier one-bit LED output peripheral; retained in hardware |
| `axi_gpio_1` | Dual-channel command/status bridge to the custom UART |
| `rst_ps7_0_100M` | Generates reset signals with the required polarities for the clock domain |
| `xlslice_0`, `xlslice_1`, `xlslice_2` | Split the command word into byte, TX request, and read request |
| `xlconcat_0` | Packs the byte and status flags into the status word |
| `uart_software_interf_0` | Instance of your VHDL `uart_software_interface` module |

The ARM accesses peripherals through `M_AXI_GP0`. SmartConnect connects `S00_AXI` to that master, `M00_AXI` to the LED GPIO, and `M01_AXI` to the UART GPIO. AXI GPIO converts memory-mapped transactions into ordinary parallel signals. It does not perform serial transmission itself.

There are two AXI GPIO IP instances, providing three used logical channels: one LED channel plus two UART channels. The UART bridge needs separate output and input paths; dual-channel GPIO packages them into one IP instance. The LED peripheral is independent and could be removed if it is no longer needed.

### Clocks and reset

The PS provides `FCLK_CLK0` at **100 MHz**, so one hardware clock period is **10 ns**. It drives the custom UART wrapper, both GPIO AXI clocks, SmartConnect, the reset controller's `slowest_sync_clk`, and the PS `M_AXI_GP0_ACLK` input.

`FCLK_RESET0_N` feeds the reset controller. Its `peripheral_aresetn` output supplies the active-low resets for SmartConnect and the GPIO IP. Its `peripheral_reset` output supplies the active-high `rst` input of the custom VHDL wrapper. The custom sequential processes apply reset at a rising clock edge.

This polarity matters: a signal named `aresetn` is asserted low, while your VHDL tests `rst = '1'`. Interchanging them can hold the circuit in reset or prevent initialization.

The baud generator produces a **clock-enable pulse**, not a new clock. TX and RX remain clocked at 100 MHz and advance their serial timing when `tick = '1'`. The GPIO command path and custom hardware share that clock domain.

### Physical I/O

DDR and FIXED_IO connect the PS to the board. The retained LED output is `led0[0]`, constrained to package pin `R14` with `LVCMOS33` in `led_pin.xdc`. The current C application does not initialize or control this LED GPIO.

The custom UART's serial link is internal. There are currently no external PL TX/RX pins to connect to a display or USB/UART adapter.

## 5. GPIO interface contract

This section is the agreement between the C program and VHDL. Both must use the same bit positions, directions, and handshake rules.

### Addresses and channel configuration

| Peripheral | Base address | Configuration |
| --- | --- | --- |
| `axi_gpio_0` | `0x41200000` | Channel 1: one output bit for LED |
| `axi_gpio_1` | `0x41210000` | Channel 1: 10 output bits; channel 2: 13 input bits |

Each peripheral has a 64 KiB assigned address range. The useful UART GPIO registers are:

| Register | Offset from UART GPIO base | Address | Use here |
| --- | --- | --- | --- |
| Channel 1 DATA | `0x00` | `0x41210000` | Write data and requests |
| Channel 1 TRI | `0x04` | `0x41210004` | Direction register where applicable |
| Channel 2 DATA | `0x08` | `0x41210008` | Read byte and status |
| Channel 2 TRI | `0x0C` | `0x4121000C` | Direction register where applicable |

The application uses the generated `XPAR_AXI_GPIO_1_BASEADDR` macro and driver channel numbers, rather than calculating these addresses manually. Recheck generated hardware definitions if you change address assignments.

Channel 1 is configured **All Outputs** and channel 2 **All Inputs** in Vivado. That fixed configuration is why the final C code does not call `XGpio_SetDataDirection()` for this GPIO. Dual-channel mode alone does not set the directions. For configurable directions, a direction-mask bit of `0` means output and `1` means input. Writing the data register for an input does not drive that input. [AMD GPIO operation](https://docs.amd.com/r/en-US/pg144-axi-gpio/Operation), [AMD GPIO data registers](https://docs.amd.com/r/en-US/pg144-axi-gpio/AXI-GPIO-Data-Register-GPIOx_DATA).

### Channel 1: software → hardware

| Bits | VHDL signal | C mask | Meaning |
| --- | --- | --- | --- |
| 7:0 | `tx_data` | `UART_DATA_MASK = 0x000000FF` | Byte to transmit |
| 8 | `tx_command` | `UART_TX_COMMAND_MASK = 0x00000100` | Rising request starts one transmission |
| 9 | `read_command` | `UART_READ_COMMAND_MASK = 0x00000200` | Rising request attempts one FIFO read |

`xlslice_0` extracts bits 7:0, `xlslice_1` extracts bit 8, and `xlslice_2` extracts bit 9. Each receives the same 10-bit GPIO output bus. These blocks select wires; they do not store data or introduce a clocked handshake.

Examples:

```text
0x00000000  → lower both requests; byte field becomes zero
0x00000155  → byte 0x55 and TX request high
0x00000200  → FIFO read request high
```

`XGpio_DiscreteWrite()` replaces the whole channel output word. Writing a read command also clears the TX request. The current helpers intentionally run sequentially; they are not safe to call concurrently without redesigning command ownership.

### Channel 2: hardware → software

| Bits | VHDL signal | C mask | Meaning |
| --- | --- | --- | --- |
| 7:0 | `fifo_data` | `UART_DATA_MASK = 0x000000FF` | Last byte produced by an accepted FIFO read |
| 8 | `fifo_empty` | `UART_FIFO_EMPTY_MASK = 0x00000100` | No unread bytes remain |
| 9 | `fifo_full` | `UART_FIFO_FULL_MASK = 0x00000200` | All 32 FIFO positions are occupied |
| 10 | `tx_busy` | `UART_TX_BUSY_MASK = 0x00000400` | Transmitter is sending a frame |
| 11 | `tx_complete` | `UART_TX_COMPLETE_MASK = 0x00000800` | Persistent TX completion flag |
| 12 | `read_complete` | `UART_READ_COMPLETE_MASK = 0x00001000` | Persistent read completion flag |

Concat order is significant: `In0` is the 8-bit `fifo_data`; `In1` through `In5` are empty, full, busy, TX completion, and read completion respectively. Its 13-bit output connects to `gpio2_io_i`.

The wrapper also has `tx_done` and `rx_error` outputs, but they are not connected to software-visible status bits in this block design. Software polls `tx_complete`, not the short `tx_done` pulse.

### How to interpret a status sample

After a fresh hardware reset, `0x00000100` means FIFO empty, output byte zero, TX idle, and both completion flags clear. The startup print uses hexadecimal formatting (`%08x`); this is not an eight-digit binary number. The program prints the expected value but does not assert equality at startup.

After reading the last byte `0x55`, the output byte remains `0x55` even though the FIFO is empty. With read completion still high, an otherwise idle status is `0x00001155`; after acknowledgement it is `0x00000155`. These are valid states. A retained output byte does not mean another unread byte exists.

Check flags with masks, for example `(status & UART_TX_COMPLETE_MASK) != 0U`. Comparing that expression to `1` would fail because bit 11 contributes `0x800`, not `1`.

## 6. VHDL modules

### Hierarchy

```text
system_wrapper / system.bd
└── uart_software_interface
    ├── command_pulse             [TX request]
    ├── command_pulse             [FIFO read request]
    └── uart_loopback_buffered
        ├── uart_loopback_core
        │   ├── uart_baud         [BAUD_RATE.vhd]
        │   ├── TX
        │   └── RX
        └── FIFO
```

`uart_pkg.vhd` supplies the UART timing constants. The older `uart2.vhd` is present in the imported sources but is not the top of this integrated hierarchy.

### 6.1 Timing package and baud generator

The current constants are `CLK_FREQ = 100000000`, `BAUD_RATE = 9600`, and `BAUD_DIV = CLK_FREQ / (BAUD_RATE * 16)`. Integer division gives **651**.

The `uart_baud` counter generates a one-clock-wide `tick` every 651 clocks. Reset clears its counter and output pulse.

```text
Clock period       = 1 / 100 MHz           = 10 ns
Tick interval      = 651 × 10 ns           = 6.51 µs
Nominal bit period = 16 × 6.51 µs          = 104.16 µs
Actual baud        = 100000000 / (651×16)  ≈ 9600.614 baud
Baud error         ≈ +0.0064%
8N1 frame          = 10 bit periods        ≈ 1.0416 ms
```

The tick runs freely. A request can arrive between ticks, so the initial start-bit timing has tick-phase alignment effects; the frame duration above is the nominal value, not a promise of identical nanosecond duration for every request.

Changing the actual PL clock requires updating the timing constants or the clock configuration so they agree. Changing the C application's PC baud rate does not change this VHDL divider.

### 6.2 TX: parallel byte to serial frame

The transmitter accepts `tx_start` while idle and captures `data_in`. The serial line idles high. A frame consists of a low start bit, eight data bits least-significant bit first, and a high stop bit.

| State | Behavior |
| --- | --- |
| `idle` | Wait for `tx_start`; capture byte, assert busy, drive start bit low |
| `data` | Use 16 tick intervals to advance from the start bit through data bits 0–7 |
| `stop` | Finish the final data-bit interval, then drive the stop bit high |
| `finish_stop` | Hold the stop interval, clear busy, pulse done, return to idle |

`tx_done` is high for one 100 MHz clock cycle. A new start pulse while busy is not queued. There is no TX FIFO. The software contract avoids this by waiting for each transmission to finish before starting another.

For byte `0x55`, the data bits on the wire are `1,0,1,0,1,0,1,0`. The most significant bit is not transmitted first.

### 6.3 RX: serial frame to parallel byte

The receiver samples the serial input through `sync1` and `sync2`; `sync2_d` stores a delayed synchronized value for falling-edge detection. The implementation therefore has two synchronization stages plus a delayed sample for detecting an edge. A source comment calling all three a synchronizer should be read with that distinction.

| Phase | Behavior |
| --- | --- |
| Idle | Detect a high-to-low transition |
| Start | Wait about half a bit, using eight ticks, and confirm the start remains low |
| Data | Sample once per bit, 16 ticks apart, into bits 0 through 7 |
| Stop | Check that the stop sample is high |

For a valid stop bit, RX updates `rx_data` and pulses `rx_done`. A low stop sample produces `f_error` instead. Both event flags are cleared on subsequent clocks. The receiver has no parity checking and no majority-vote sampling; the 16× tick establishes sample timing.

Although a comment in RX refers to seven bits, the actual bit counter covers eight data bits. This guide describes the implemented logic.

### 6.4 Core and buffered wrapper

`uart_loopback_core` shares the baud tick between TX and RX and connects TX's serial output to RX's serial input internally. Its purpose is to test serialization and reconstruction without requiring an external cable.

`uart_loopback_buffered` adds the FIFO. RX's completed byte feeds `data_in`, and `rx_done` feeds the write request. Since the modules are clocked processes, the FIFO sees the newly asserted RX done/data pair at the following rising edge.

Sharing a tick makes this an effective internal integration test, but it does not establish tolerance to an external sender with an independent clock or different baud error.

### 6.5 FIFO: 32 stored bytes

The FIFO stores **32 × 8 bits** and has read/write pointers and an occupancy count. Both interfaces use the same 100 MHz clock. It is not an asynchronous clock-domain-crossing FIFO.

Reset clears the pointers, occupancy, and output byte. It does not erase every storage location; clearing occupancy makes the old stored contents unavailable as valid queued data.

Reads are registered: an accepted read updates `data_out` after that clock edge. `data_out` holds its last value until another accepted read or reset. It does not continuously show the next unread byte.

| State before edge | Requested operations | Accepted operations | Count change |
| --- | --- | --- | --- |
| Neither empty nor full | Read only | Read | −1 |
| Neither empty nor full | Write only | Write | +1 |
| Neither empty nor full | Read and write | Both | 0 |
| Empty | Read only | Neither | 0 |
| Empty | Read and write | Write only | +1 |
| Full | Write only | Neither | 0 |
| Full | Read and write | Read only | −1 |

Acceptance uses the count **before** the edge. Consequently, a simultaneous read does not rescue a write requested while full, and a simultaneous write does not provide immediate fall-through data to a read while empty.

If RX delivers another byte while full, that new byte is dropped. The design exposes the full level but does not record a persistent overflow event.

## 7. Why the command and completion logic exists

### 7.1 One request must cause one operation

A GPIO output stays at its last written value until software changes it. A CPU request can therefore remain high for many FPGA clocks. If a FIFO treated that high level as a read enable every clock, one software request could drain many bytes. A held TX request could start another transmission when TX returns to idle.

`command_pulse` stores the previous command value and produces a registered, one-cycle pulse only when the current value is high and the previous value was low. Holding the command high generates no additional pulses. Software must lower it before making another request.

This is an **edge detector**. It is not a mechanical-switch debounce filter and does not, by itself, safely synchronize an arbitrary asynchronous input. Here the command arrives through GPIO in the same clock domain.

After reset, its previous value is zero. A command already high when reset is released can therefore be interpreted as a new request. The application initializes commands to zero and relies on a correctly reset hardware system.

### 7.2 A one-cycle result is too brief for polling

The TX done pulse lasts 10 ns. C polling through AXI is not guaranteed to sample that instant. The wrapper converts it into `tx_complete`, which stays high while `tx_command` remains high. Software can detect it later and acknowledge it by lowering its request.

The same persistent completion convention is used for FIFO reads. It tells software that the returned byte has been made valid, independently of whether the FIFO has become empty.

### 7.3 Four-phase handshake

```text
Phase                     Software request      Hardware completion
Idle                              0                       0
Request operation                 1                       0
Operation finishes                1                       1
Software acknowledges             0                       1 → 0
Ready for next operation          0                       0
```

Software raises the request, waits for completion high, lowers the request, and waits for completion low. The final wait prevents the next transaction from mistaking an old completion flag for a new result.

For TX, software must present the byte together with the request and hold the request until completion. TX captures the byte when it accepts the resulting pulse.

### 7.4 Read timing, edge by edge

Assume the FIFO is not empty and `read_command` becomes high before edge A. These are custom-wrapper clock edges, not the time measured from the beginning of an AXI write.

| Rising edge | Pulse generator | FIFO | Completion process |
| --- | --- | --- | --- |
| A | Detects the rising request; schedules read pulse high | Sees the previous low pulse | No accepted read yet |
| B | Schedules pulse low | Sees pulse high; reads byte; updates output | Records `read_pending = 1` because the read was accepted |
| C | Pulse remains low | No second read | Sees previous pending value; asserts `read_complete` |

VHDL signal assignments in clocked processes take effect after the processes evaluate. Another process running on the same edge sees the previous signal values. This explains the staging; it does not mean production logic should avoid rising edges.

If the accepted read removes the last byte, `fifo_empty` becomes high after edge B. Completion still asserts at C because `read_pending` remembers that a valid read happened. Testing only the current empty flag would lose this information.

If a request is raised while empty, the FIFO rejects it and no read completion is generated. Keeping the request high will not retry when a byte arrives later. That is why C waits for nonempty **before** raising the read request.

### 7.5 Why earlier tests held a command for five cycles

Holding a request for several cycles tests that only one operation occurs even when software is slow to lower it. Five cycles was a test stimulus duration, not the software interface's required delay. The C program uses completion flags instead of a fixed five-cycle wait. The later held-command test keeps TX requested even after TX finishes, which also tests against accidental retransmission.

## 8. C application structure

The final application separates the application policy from the GPIO handshakes. The helpers perform one operation; `main()` decides what to do with the result.

### 8.1 Startup and main loop

1. Call `init_platform()`.
2. Initialize the UART GPIO driver object with `XPAR_AXI_GPIO_1_BASEADDR`. On failure, print an error, clean up, and return failure.
3. Write zero to channel 1 so both commands are low.
4. Print the ready message and initial channel-2 status.
5. Block in `inbyte()` until a PC character arrives.
6. Exit if it is uppercase `Q`.
7. Call `uart_transmit_byte()` and then `uart_receive_byte()`.
8. Require the received byte to match the transmitted byte and the FIFO to be empty after this single-byte transaction.
9. Echo the verified byte with `outbyte()` and repeat.
10. On quit or an error after initialization, lower commands, call `cleanup_platform()`, and return the result.

The equality check and final empty check belong to this loopback demonstration. They would not be valid general rules for a display that sends independent messages or keeps multiple bytes queued.

### 8.2 Helper contracts

| Function | Inputs | Result | Responsibilities |
| --- | --- | --- | --- |
| `uart_wait_status()` | GPIO pointer, bit mask, expected masked value | Last complete status sample | Poll until condition matches or attempt limit is reached |
| `uart_transmit_byte()` | GPIO pointer, one `u8` byte | `XST_SUCCESS` or `XST_FAILURE` | Raise TX command, await completion, acknowledge, await clear |
| `uart_receive_byte()` | GPIO pointer, pointer to result byte | `XST_SUCCESS` or `XST_FAILURE` | Await nonempty, request read, capture valid byte, acknowledge, await clear |

All three helpers are declared `static`: their function names are private to this C source file. The prototypes near the top allow `main()` to call helpers whose bodies appear later.

### 8.3 Polling helper

`uart_wait_status()` repeatedly reads channel 2 and checks `(gpio_status & mask) == expected`.

- `expected = mask` waits for all selected bits to be high.
- `expected = 0U` waits for all selected bits to be low.
- The function returns the full sampled word, including byte and other flags.
- Reaching `UART_POLL_LIMIT = 1000000U` also returns a sample. The caller must inspect the returned flag to distinguish success from timeout.

The limit counts reads; it is not a calibrated number of milliseconds. The CPU actively polls while waiting. `inbyte()` is also blocking, but its wait is for a PC character rather than for the custom peripheral.

### 8.4 Transmit helper

The command word is `(u32)byte | UART_TX_COMMAND_MASK`. For `byte = 0x55`, this is `0x155`. One GPIO write presents both the data and the request.

The helper waits for `tx_complete`, writes zero to acknowledge, and waits for completion to clear. If completion fails to arrive, it prints the corresponding timeout and lowers the command. A clear timeout is also reported as failure.

There is no initial wait for busy in this helper. Its precondition is that calls are sequential and the previous operation has completed; it is not an arbitrary multi-client transmitter service.

### 8.5 Receive helper

The helper first waits for `fifo_empty` to clear. It then writes `UART_READ_COMMAND_MASK` and waits for `read_complete`.

When completion is observed, it extracts the data from **that same status sample**: `(u8)(gpio_status & UART_DATA_MASK)`. It then lowers the command and waits for completion to clear. Only after the whole handshake succeeds does it write the received value through the caller's pointer and return success.

Waiting for TX completion alone is not a replacement for checking FIFO availability. Serial reception and FIFO insertion have their own timing, and an external receiver path could have different behavior.

### 8.6 Pointers and masks in this project

`XGpio uart` is a driver object that contains information such as the device's base address. `&uart` means “the address of this driver object”; the helper parameter `XGpio *uart` receives that address.

`&rx_byte` means “where the caller wants the received byte stored.” Inside the helper, `*byte = received` writes to that location. This lets the function return success/failure while separately returning an 8-bit data value. The caller must not use the result byte after a failed call.

`u8` holds an unsigned byte. `u32` holds the combined 32-bit register value. The current TX byte is already `u8`, so no extra `& 0xFF` is necessary before combining it with the command. For a wider value, masking makes the intended eight-bit field explicit and prevents higher bits from setting request bits.

```text
0x55 | 0x100  = 0x155    OR adds the TX request bit
0x1155 & 0xFF = 0x55    AND extracts the byte field
0x1155 & 0x1000         tests the read-complete field
```

A mask does not allow one UART frame to carry more than eight data bits. To send a larger number, split it into several bytes and define their order and message format.

The current generated driver configuration accepts a base address in `XGpio_Initialize()`. Examples from older non-SDT platforms may instead use a device ID. Follow the signature in this platform's generated `xgpio.h`, rather than mixing the two styles.

### 8.7 Error and exit behavior

The application stops on initialization failure, handshake timeout, loopback mismatch, or unexpected remaining FIFO data. It does not silently continue after an uncertain transaction.

Lowering the GPIO command acknowledges or cancels the request level; it does **not** reset the FIFO or abort a frame already being transmitted. `cleanup_platform()` is not a substitute for resetting custom PL hardware. After an uncertain timeout, rerun with a proper system/hardware reset before assuming a clean state.

Uppercase `Q` is consumed as a quit command and is not echoed. Lowercase `q`, digits `0` and `1`, spaces, and punctuation are ordinary payload characters in this version. The old LED commands are no longer implemented. Echo output adds no line ending; line breaks occur only if corresponding characters are sent.

## 9. A worked transaction: sending A

The ASCII byte for `A` is `0x41`.

| Step | Action | Relevant value or event |
| --- | --- | --- |
| 1 | HTerm sends A; PS UART0 receives it | `inbyte()` returns `0x41` |
| 2 | ARM raises TX request with data | Channel 1 = `0x141` |
| 3 | Edge detector pulses TX start | TX captures `0x41` |
| 4 | TX sends a frame; RX samples it | Internal serial connection, approximately 9600 baud |
| 5 | RX produces a byte | FIFO accepts `0x41` on the following clock |
| 6 | TX completion is recorded | Status bit 11 becomes high |
| 7 | ARM acknowledges TX | Channel 1 = `0`; wait for bit 11 low |
| 8 | ARM verifies data is available | Wait for status bit 8 low |
| 9 | ARM requests FIFO read | Channel 1 = `0x200` |
| 10 | FIFO output becomes valid; completion follows | Status bit 12 high, low byte `0x41` |
| 11 | ARM copies byte and acknowledges read | Channel 1 = `0`; wait for bit 12 low |
| 12 | ARM checks match and FIFO empty | Received `0x41` equals sent `0x41` |
| 13 | ARM echoes the result | `outbyte(0x41)` sends A through PS UART0 |

The exact relative timing of FIFO arrival and TX completion is not assumed by the software; it checks the necessary condition at each stage.

## 10. Rebuild, export, and run

The inspected project uses Vivado/Vitis **2026.1**. UI labels can vary between tool releases. Keep hardware, platform, and application versions aligned.

### 10.1 Decide which build is needed

| Change | Required work |
| --- | --- |
| C messages, application logic, helper code | Rebuild application and rerun it |
| VHDL, GPIO widths, wiring, address map, PS clock, constraints | Rebuild hardware, export updated XSA, update/build platform, rebuild application, program and run |
| Testbench only | Rerun simulation; no board bitstream change required |

### 10.2 Hardware in Vivado

1. Open the active `.xpr` listed in Section 3.
2. Save edited HDL and block design files. Confirm the changes were made to this project's active copies.
3. Open `system.bd`. If module ports changed, refresh the module reference and reconnect affected signals.
4. Compare GPIO widths, slices, concat order, clock/reset connections, and addresses with Sections 4–5.
5. Validate the block design. Resolve new errors and understand warnings before continuing.
6. Generate block-design output products when needed, and use the Vivado-managed HDL wrapper with `system_wrapper` as synthesis top.
7. Run synthesis, implementation, and Generate Bitstream.
8. Inspect timing and DRC results, not just the final “completed” message.
9. Export hardware with the bitstream included. Save the intended updated handoff as `./system_wrapper.xsa`.

Earlier validation showed negative PS DDR DQS-to-clock delay warnings for preset parameters. This guide does not change or certify those board-specific DDR timing values. Keep the board preset consistent with the actual board and investigate any new DDR initialization failures; do not set values to zero merely to hide a warning.

### 10.3 Update the Vitis platform

1. Open `./vitis_workspace`.
2. Select the platform component `arty_uart0_platform` and open its settings / `vitis-comp.json` view.
3. Use the hardware specification update action, such as **Switch XSA** or the available re-read action, to load the newly exported root `system_wrapper.xsa`.
4. Check that the hardware specification includes `axi_gpio_1` at the expected address.
5. Build the platform, then build `hello_world`.
6. Confirm the application still targets `standalone_ps7_cortexa9_0` and `ps7_cortexa9_0`.

AMD's documented update flow explicitly updates the XSA reference and rebuilds the platform; exporting from Vivado alone does not perform that platform update. [AMD Vitis hardware update guide](https://docs.amd.com/r/en-US/ug1165-zynq-embedded-design-tutorial/Updating-Hardware-in-the-Vitis-Software-Platform).

In this BSP, standard input and output both use PS UART0 at base `0xE0000000`. That is why `inbyte()`, `outbyte()`, `print()`, and `xil_printf()` communicate with the same terminal.

### 10.4 Launch configuration

The saved launch configuration is `hello_world_app_hw_1` in the application's `_ide/launch.json`. It enables system reset, device programming, PS7 initialization, PS7 post-initialization, and processor reset. It targets Cortex-A9 core 0 and does not stop at application entry.

Its relevant assets are:

```text
hello_world/_ide/bitstream/system_wrapper.bit
hello_world/_ide/psinit/ps7_init.tcl
hello_world/build/hello_world.elf
```

These paths are relative to the active Vitis workspace. The launch currently uses PS initialization Tcl (`isFsbl: false`), rather than the alternative FSBL mode also represented in the configuration. Do not mix stale launch assets with a newly exported platform.

If Vitis reports that a task is already running, stop the existing application/debug launch before launching again. Avoid starting a second competing session against the same target.

### 10.5 Board and HTerm

1. Power the board and connect the PC through the micro-USB JTAG/UART connection with a data-capable cable.
2. Identify its current COM port. The COM number is PC-dependent and is not fixed by this project.
3. Connect HTerm at **115200 baud, 8 data bits, no parity, 1 stop bit**, without hardware flow control for this demonstration. Do not select 9600 for the PC link.
4. Close other serial-terminal connections to the same COM port. Disable local echo if enabled, so received characters are not confused with locally displayed typing.
5. Launch the built application with the saved hardware configuration. Keep HTerm connected before launch to capture the startup messages.
6. Wait for `UART loopback ready. Q = quit` and inspect the startup status.
7. Send individual ASCII characters. Expect the same characters back, without extra per-byte debug text.
8. Send uppercase `Q` when finished. The current program exits without echoing Q or printing the older LED shutdown message.

JTAG loading is a development workflow. This project has not established a persistent custom boot image that automatically restores the application and PL after power cycling. Existing factory/flash software can print its own banner. Seeing `Arty Z7 -Z20 Rev. B Demo Image` alone does not identify the current custom bitstream or application.

## 11. Verification and evidence

### 11.1 Simulation coverage accumulated during development

| Test | Main purpose | Evidence and limits |
| --- | --- | --- |
| `uart_sim.v` | Core serial TX/RX loopback for `20 FF 33 55 AA 80 01` | User reported seven PASSED results; tests several bit patterns |
| `UART_sim_buffered.v` | Send seven bytes, then read them in order | User reported all seven values in order |
| `command_pulse_sim.v` | Observe pulse generation for held and repeated commands | Waveform inspection; not a comprehensive assertion test |
| `uart_software_interface_sim.v` | Command interface, buffered data order, final empty | Seven-byte interface test; holding a request for five cycles checks level-to-pulse behavior |
| `uart_held_command_sim.v` | Persistent request/completion behavior | Held TX request after completion, no repeated transmission, single read, completion clear, final empty |
| Earlier FIFO simulation | Standalone FIFO behavior | User reported prior simulation; exhaustive boundary coverage was not established here |

The currently selected simulation top is `uart_held_command_sim`. Its TX command is held for another 200000 clock cycles, about 2 ms at 100 MHz, after completion. It also checks read completion persistence and clearing, and contains a 10 ms watchdog. The user reported a received `55`, completion cleared, and no more bytes to read.

Testbench stimulus often changes on falling edges so it is stable before the next rising edge. The synthesized hardware still uses rising-edge registers. In Verilog testbench checks, case equality `===` and inequality `!==` make unknown values explicit; they are useful when a test must fail instead of overlooking an X/Z value.

To rerun a test, select its simulation top, launch behavioral simulation, and run long enough for the UART frames and watchdog. The initial 1000 ns default run is much shorter than one approximately 1 ms UART frame. A `run 10 ms` command is sufficient to reach the current held-command test's watchdog; a passing test finishes earlier. Check console assertions as well as waveforms.

### 11.2 Routed timing

The inspected `system_wrapper_timing_summary_routed.rpt` reports a 100 MHz `clk_fpga_0` clock:

| Measure | Result |
| --- | --- |
| Worst setup slack, WNS | +3.505 ns |
| Total negative setup slack, TNS | 0.000 ns |
| Worst hold slack, WHS | +0.037 ns |
| Total negative hold slack, THS | 0.000 ns |
| Worst pulse-width slack, WPWS | +3.750 ns |
| Failing setup / hold / pulse-width endpoints | 0 / 0 / 0 |
| Unconstrained internal endpoints | 0 |
| Output ports without output-delay constraint | 1 |

The report states that all user-specified timing constraints are met. Positive setup slack means data arrives with margin before the sampling deadline; positive hold slack means the minimum-delay requirement is met. Pulse-width slack checks the required clock pulse durations.

The report also flags one output without an output-delay constraint. The visible fabric output is the LED, but the excerpt does not name the port; confirm it in Vivado before treating the warning as explained. Do not generalize this timing pass to an external UART pin interface that has not yet been added or constrained. Timing success also does not prove protocol correctness.

### 11.3 Board results reported by you

The fixed-byte test reported:

```text
transmission complete
Transmit handshake finished
Received byte: 55
Read handshake finished
UART loopback passed
```

The interactive test later returned `A`, `W`, `1`, and `G`, with diagnostic receive values `41`, `57`, `31`, and `47`. After removing routine per-byte diagnostics and refactoring into helpers, you reported:

```text
UART loopback ready. Q = quit
starting status expected: (00000100) => 00000100
asdfghjklrfvb hjk,l ff g h g
```

This supports successful end-to-end operation for the tested manual input, including spaces and punctuation. It does not establish error-free performance for long bursts, all 256 byte values, or an external serial device.

### 11.4 Useful additional tests

These are proposed coverage extensions, not completed results:

1. Exercise FIFO capacity, pointer wraparound, and simultaneous read/write at empty and full.
2. Apply invalid stop bits and verify framing-error behavior and recovery.
3. Inject a request while TX is busy or the FIFO is empty and confirm the documented outcome.
4. Reset during a frame and during each handshake phase; verify a clean restart.
5. Use independently timed TX/RX stimulus and varied start phase to assess external baud tolerance.
6. Send paced long sequences with automatic byte comparison, then increase input rate to measure loss.
7. Test every byte value with a separate binary test mode that does not reserve Q or mix diagnostic text with payload.

## 12. Performance and current limitations

The PC link can carry about `115200 / 10 = 11520` 8N1 characters per second. The custom UART can carry about `9600 / 10 = 960` characters per second, before software overhead. The slow serial link is therefore the main throughput limit.

The application processes one byte from start to finish before reading the next PC byte. During that interval, more PC characters can accumulate in the PS UART receive buffer. A long unpaced burst can overflow that ingress buffer. The 32-byte PL FIFO is farther downstream and cannot protect the PS receive buffer from that mismatch.

The current design has no software receive queue, interrupt-driven processing, DMA, or end-to-end flow control. It is intended for paced interactive testing. The PL FIFO is useful hardware, but this particular main loop normally uses only a single outstanding byte.

Other limits to remember:

- No queued TX requests: a pulse while busy can be lost.
- No persistent software-visible framing-error or overflow flag.
- No automatic retry or hardware recovery after timeout.
- Polling limits count attempts rather than elapsed time.
- Q cannot interrupt an already-running helper; it is recognized when the main loop next reads PC input.
- Shared-clock internal loopback does not test external electrical connections or independent baud drift.
- Whole-channel command writes and helper sequencing assume a single software owner.
- The application reserves one byte value for quitting and includes startup/error text, so it is not a transparent binary bridge.

## 13. Troubleshooting

| Symptom | Likely checks |
| --- | --- |
| No COM port | Board power, USB data cable, correct connector, PC driver/device enumeration |
| COM exists but no ready message | Actual application launch, terminal opened before launch, correct COM, PS standard I/O configuration |
| Garbled startup text | PC link set to 115200 8N1; do not use the custom UART's 9600 setting |
| Only the demo image banner appears | Factory/old software may be running; verify the selected ELF, bitstream, and successful launch |
| “Task is already running” | Stop the prior run/debug task, then launch the intended configuration |
| Duplicate platform/app names | Open `vitis_workspace`; inspect actual component paths |
| Initial status is not `0x100` | Confirm fresh reset, current bitstream, GPIO base, concat order; remember retained byte data can make later idle values differ |
| TX completion timeout | Command bit/slice, clock/reset, TX start pulse, busy state, completion mapping, stale hardware |
| FIFO-data timeout | RX serial connection/timing, framing error, FIFO write path; TX completion does not prove successful RX |
| Read completion timeout | Request made while empty, missing new command edge, incorrect pending logic, swapped status bits |
| Completion never clears | Request still high, wrong GPIO write/channel, wrong completion bit, reset or stale platform issue |
| Same byte repeats | Held level reaching TX/FIFO directly, missing edge detector, incorrect acknowledgement sequencing |
| Correct individual characters, loss on paste | PC input rate exceeds blocking loop throughput; pace input and consider buffering/flow control |
| Echo appears twice | Check terminal local echo and accidental retransmission separately |
| Character comparison fails | Data slice, FIFO validity timing, bit order, masks, unexpected queued bytes |
| New C runs against old hardware | Re-export XSA, update platform, rebuild app, verify launch bitstream assets |

Debug in layers: first confirm the correct PS application is running, then validate GPIO startup status, then command/completion behavior, then serial TX/RX and FIFO events. A logic analyzer core can later expose internal hardware signals, but it is not part of this saved design.

## 14. Extending the project to an external device

The architecture is a useful foundation for a display or other serial device: hardware handles bit timing and buffering, while C handles message meaning. Moving from internal loopback to external communication requires an initial hardware change as well as application changes.

### Hardware changes

1. Expose a serial TX output and an independent serial RX input through the core and wrapper ports.
2. Replace the internal TX-to-RX loopback wire with these external paths.
3. Add top-level ports and suitable board pin constraints and I/O standards.
4. Connect TX to the device's RX, RX to its TX, and a common ground; verify compatible signal voltages and use appropriate level conversion when needed.
5. Configure baud rate and framing to match the device, then simulate and rebuild the hardware.

### Software changes

1. Keep the low-level handshake helpers if the GPIO contract remains unchanged.
2. Remove loopback-only requirements that received data equals the just-sent byte and that the FIFO must immediately become empty.
3. Define command/response framing, byte order, terminators or lengths, and error handling from the device's protocol.
4. Handle unsolicited and multi-byte responses, with buffering and timeout policies appropriate to that device.
5. Avoid blocking PC input or a transmit operation so long that incoming external data overflows the FIFO.

Once the external pins and protocol-independent hardware are established, many future behavior changes can be made in C alone. A changed baud rate, incompatible frame format, insufficient FIFO depth, or new hardware status signals can still require a new bitstream.

An eventual custom AXI-Lite peripheral could replace the GPIO slices/concat with dedicated data, command, status, and error registers. That is an architectural improvement to consider after this version is understood and tested, not a requirement for the current working demonstration.

## 15. Learning reference

| Term | Meaning in this project |
| --- | --- |
| UART | Asynchronous serial framing with start, data, and stop bits |
| 8N1 | Eight data bits, no parity, one stop bit |
| Baud | Serial symbol rate; for this binary UART, approximately the bit rate |
| GPIO | Parallel general-purpose input/output signals, used here as registers connected to custom logic |
| AXI | The on-chip bus used by the ARM to access PL peripherals |
| Memory-mapped I/O | Reading/writing addresses that access hardware registers |
| FIFO | First-in, first-out storage preserving byte order |
| Clock enable | A signal permitting an update on selected edges of an existing clock |
| Handshake | A request/completion/acknowledgement sequence coordinating participants |
| Persistent completion | A result flag retained long enough for software to observe and acknowledge it |
| Synchronizer | Registers that reduce the risk of metastability propagating from an asynchronous input |
| BSP | Board support package: generated hardware definitions, drivers, and runtime support |
| Synthesis | Translation of HDL into implementable logic |
| Implementation | Placement and routing of that logic in the device |
| Bitstream | Configuration data that realizes the PL hardware |
| ELF | Executable containing the compiled ARM application |

VHDL and Verilog both describe hardware; this project uses VHDL for the design and Verilog for its testbenches. C runs instructions on the processor. A loop in C repeatedly executes software operations; a clocked VHDL process describes registers and their next-state behavior. Understanding that difference explains why a level held for a short time in C can span many hardware operations.

## 16. Source index and document maintenance

All short paths below are relative to `.`. The accompanying `source_manifest.json` records full paths, sizes, modification times, and SHA-256 fingerprints for the inspected sources and key artifacts. It identifies the files this guide was prepared against; it is not a replacement for source control or a project backup.

| Area | Files |
| --- | --- |
| UART implementation | `hardware/arty_z7_hello.srcs/sources_1/imports/new/uart_pkg.vhd`, `BAUD_RATE.vhd`, `TX.vhd`, `RX.vhd`, `FIFO.vhd` in the same directory |
| Integration wrappers | `hardware/arty_z7_hello.srcs/sources_1/new/uart_loopback_core.vhd`, `uart_loopback_buffered.vhd`, `command_pulse.vhd`, `uart_software_interface.vhd` |
| Block design | `hardware/arty_z7_hello.srcs/sources_1/bd/system/system.bd` |
| LED constraint | `hardware/arty_z7_hello.srcs/constrs_1/new/led_pin.xdc` |
| Core simulation | `hardware/arty_z7_hello.srcs/sim_1/imports/new/uart_sim.v` |
| Additional simulations | Sources under `hardware/arty_z7_hello.srcs/sim_1/new/`; see manifest for exact filenames |
| ARM application | `vitis_workspace/hello_world/src/helloworld.c` |
| Platform configuration | `vitis_workspace/arty_uart0_platform/vitis-comp.json` |
| Launch configuration | `vitis_workspace/hello_world/_ide/launch.json` |
| Current exported hardware | `system_wrapper.xsa` |
| Timing evidence | `hardware/arty_z7_hello.runs/impl_1/system_wrapper_timing_summary_routed.rpt` |

When changing the project, update the bit map, clock/baud values, handshake contract, file locations, and verification section together. A documentation statement of a passed test should identify an actual result; proposed tests should remain clearly marked as proposed.

### External references

The project files are the primary source for this guide's specific implementation. These AMD references support the general GPIO behavior and hardware-update workflow:

- [AXI GPIO operation and directions](https://docs.amd.com/r/en-US/pg144-axi-gpio/Operation).
- [AXI GPIO data register behavior](https://docs.amd.com/r/en-US/pg144-axi-gpio/AXI-GPIO-Data-Register-GPIOx_DATA).
- [Updating hardware in a Vitis platform](https://docs.amd.com/r/en-US/ug1165-zynq-embedded-design-tutorial/Updating-Hardware-in-the-Vitis-Software-Platform).

**End of revision 1.** The documentation describes the saved implementation and reported test evidence; no project source was changed to produce it.

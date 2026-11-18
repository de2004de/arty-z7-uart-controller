/******************************************************************************
* Copyright (C) 2023 Advanced Micro Devices, Inc. All Rights Reserved.
* SPDX-License-Identifier: MIT
******************************************************************************/
/*
 * HTerm -> PS UART0 -> ARM -> FPGA UART TX/RX/FIFO -> ARM -> PS UART0 -> HTerm.
 * PS UART0 uses 115200 baud; the internal FPGA UART uses 9600 baud.
 * Send characters individually for this blocking loopback demonstration.
 */

#include "platform.h"
#include "xil_printf.h"
#include "xparameters.h"
#include "xgpio.h"
#include "xstatus.h"

#define UART_COMMAND_CHANNEL    1U
#define UART_STATUS_CHANNEL     2U
#define UART_POLL_LIMIT         1000000U  // Attempt limit, not a duration.

// Channel 1: bits 7:0 carry data; bits 8 and 9 request operations.
#define UART_DATA_MASK          0xFFU
#define UART_TX_COMMAND_MASK    (1U << 8)
#define UART_READ_COMMAND_MASK  (1U << 9)

// Channel 2: bits 7:0 carry the last FIFO output byte.
#define UART_FIFO_EMPTY_MASK    (1U << 8)
#define UART_FIFO_FULL_MASK     (1U << 9)
#define UART_TX_BUSY_MASK       (1U << 10)
#define UART_TX_COMPLETE_MASK   (1U << 11)
#define UART_READ_COMPLETE_MASK (1U << 12)

// Function declarations let main() appear before the function implementations.
static u32 uart_wait_status(XGpio *uart, u32 mask, u32 expected);
static int uart_transmit_byte(XGpio *uart, u8 byte);
static int uart_receive_byte(XGpio *uart, u8 *byte);

int main(void)
{
    XGpio uart;
    int result = 0;
    u32 gpio_status;

    init_platform();

    if (XGpio_Initialize(&uart, XPAR_AXI_GPIO_1_BASEADDR) != XST_SUCCESS)
    {
        print("UART GPIO initialization failed.\r\n");
        cleanup_platform();
        return 1;
    }

    // Both channel directions are fixed in Vivado. Start with commands low.
    XGpio_DiscreteWrite(&uart, UART_COMMAND_CHANNEL, 0U);
    print("UART loopback ready. Q = quit\r\n");
    gpio_status = XGpio_DiscreteRead(&uart, UART_STATUS_CHANNEL);
    xil_printf("starting status expected: (00000100) => %08x\r\n",
               (unsigned int)gpio_status);

    while (1)
    {
        // Read one character from the PC through PS UART0.
        u8 tx_byte = (u8)inbyte();
        u8 rx_byte;

        if (tx_byte == 'Q')
        {
            break;
        }

        // Send through the custom FPGA UART, then retrieve its received byte.
        if (uart_transmit_byte(&uart, tx_byte) != XST_SUCCESS)
        {
            result = 1;
            break;
        }
        if (uart_receive_byte(&uart, &rx_byte) != XST_SUCCESS)
        {
            result = 1;
            break;
        }

        // These checks belong to the loopback application, not the UART driver.
        if (rx_byte != tx_byte)
        {
            xil_printf("Loopback mismatch: expected %02x, received %02x\r\n",
                       (unsigned int)tx_byte, (unsigned int)rx_byte);
            result = 1;
            break;
        }

        gpio_status = XGpio_DiscreteRead(&uart, UART_STATUS_CHANNEL);
        if ((gpio_status & UART_FIFO_EMPTY_MASK) == 0U)
        {
            print("Loopback error: unexpected bytes remain in the FIFO.\r\n");
            result = 1;
            break;
        }

        // Echo the verified FPGA result to the PC through PS UART0.
        outbyte(rx_byte);
    }

    // All post-initialization exits use this cleanup, including timeouts.
    XGpio_DiscreteWrite(&uart, UART_COMMAND_CHANNEL, 0U);
    cleanup_platform();
    return result;
}

// Wait for selected status bits to match expected; return the last full sample.
// Callers MUST check the returned bits: reaching the attempt limit is possible.
// expected = mask waits for set bits; expected = 0 waits for cleared bits.
static u32 uart_wait_status(XGpio *uart, u32 mask, u32 expected)
{
    u32 gpio_status = 0U;

    for (u32 attempt = 0U; attempt < UART_POLL_LIMIT; attempt++)
    {
        gpio_status = XGpio_DiscreteRead(uart, UART_STATUS_CHANNEL);
        if ((gpio_status & mask) == expected)
        {
            break;
        }
    }
    return gpio_status;
}

// Complete one transmit handshake. Call sequentially, with commands initially low.
static int uart_transmit_byte(XGpio *uart, u8 byte)
{
    u32 gpio_status;
    u32 command = (u32)byte | UART_TX_COMMAND_MASK;

    // 1. Present the byte and raise the transmit request.
    XGpio_DiscreteWrite(uart, UART_COMMAND_CHANNEL, command);

    // 2. Keep the request high until hardware reports completion.
    gpio_status = uart_wait_status(uart, UART_TX_COMPLETE_MASK,
                                   UART_TX_COMPLETE_MASK);
    if ((gpio_status & UART_TX_COMPLETE_MASK) == 0U)
    {
        print("Timeout waiting for transmission completion.\r\n");
        XGpio_DiscreteWrite(uart, UART_COMMAND_CHANNEL, 0U);
        return XST_FAILURE;
    }

    // 3. Lower the request and wait for hardware to clear completion.
    XGpio_DiscreteWrite(uart, UART_COMMAND_CHANNEL, 0U);
    gpio_status = uart_wait_status(uart, UART_TX_COMPLETE_MASK, 0U);
    if ((gpio_status & UART_TX_COMPLETE_MASK) != 0U)
    {
        print("Timeout clearing transmit completion.\r\n");
        return XST_FAILURE;
    }
    return XST_SUCCESS;
}

// Complete one FIFO read handshake. Store the byte through the supplied pointer.
// The caller uses that byte only when this function returns XST_SUCCESS.
static int uart_receive_byte(XGpio *uart, u8 *byte)
{
    u32 gpio_status;
    u8 received;

    // 1. Wait until the FIFO contains data.
    gpio_status = uart_wait_status(uart, UART_FIFO_EMPTY_MASK, 0U);
    if ((gpio_status & UART_FIFO_EMPTY_MASK) != 0U)
    {
        print("Timeout waiting for FIFO data.\r\n");
        return XST_FAILURE;
    }

    // 2. Request one read and wait until its output byte is ready.
    XGpio_DiscreteWrite(uart, UART_COMMAND_CHANNEL, UART_READ_COMMAND_MASK);
    gpio_status = uart_wait_status(uart, UART_READ_COMPLETE_MASK,
                                   UART_READ_COMPLETE_MASK);
    if ((gpio_status & UART_READ_COMPLETE_MASK) == 0U)
    {
        print("Timeout waiting for read completion.\r\n");
        XGpio_DiscreteWrite(uart, UART_COMMAND_CHANNEL, 0U);
        return XST_FAILURE;
    }
    received = (u8)(gpio_status & UART_DATA_MASK);

    // 3. Acknowledge the read and wait for the completion flag to clear.
    XGpio_DiscreteWrite(uart, UART_COMMAND_CHANNEL, 0U);
    gpio_status = uart_wait_status(uart, UART_READ_COMPLETE_MASK, 0U);
    if ((gpio_status & UART_READ_COMPLETE_MASK) != 0U)
    {
        print("Timeout clearing read completion.\r\n");
        return XST_FAILURE;
    }

    *byte = received;
    return XST_SUCCESS;
}

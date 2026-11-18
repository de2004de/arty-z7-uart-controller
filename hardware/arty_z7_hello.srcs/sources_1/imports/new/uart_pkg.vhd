----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 09/20/2026 03:07:32 PM
-- Design Name: 
-- Module Name: uart_pkg - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;

package uart_pkg is

    constant CLK_FREQ  : integer := 100_000_000;  -- 100 MHz FPGA clock
    constant BAUD_RATE : integer := 9_600;

    constant BAUD_DIV : integer := CLK_FREQ / (BAUD_RATE * 16);

end package;

package body uart_pkg is
end package body;
----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 09/22/2026 05:40:29 PM
-- Design Name: 
-- Module Name: TX - Behavioral
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
use ieee.numeric_std.all;
use work.uart_pkg.all;

entity uart_baud is
    port(
        clk  :in  std_logic;
        rst  :in  std_logic;
        tick :out std_logic
    );
end entity;

architecture rtl of uart_baud is
    signal counter :integer range 0 to BAUD_DIV:= 0;
    signal tick_r  :std_logic := '0';
    
begin
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                counter <= 0;
                tick_r  <= '0';
            else
                if counter = BAUD_DIV - 1 then
                    counter <= 0;
                    tick_r  <= '1';
                else
                    counter <= counter + 1;
                    tick_r  <= '0';
                end if;
            end if;
        end if;
    end process;

    tick <= tick_r;

end architecture;
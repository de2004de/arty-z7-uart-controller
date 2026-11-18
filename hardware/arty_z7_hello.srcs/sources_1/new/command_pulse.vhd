----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 11/10/2026 06:50:45 PM
-- Design Name: 
-- Module Name: command_pulse - Behavioral
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


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity command_pulse is
    Port ( 
        clk     : in  STD_LOGIC;
        rst     : in  STD_LOGIC;
        command : in  STD_LOGIC;
        pulse   : out STD_LOGIC
    );  
end command_pulse;

architecture Behavioral of command_pulse is
    signal previous_command : std_logic;
    
begin
    process(clk)
    begin 
        if rising_edge(clk) then
        
            -- check reset condition
            if rst = '1' then 
                previous_command <= '0';
                pulse            <= '0';
            
            -- check conditions
            else 
                -- assert pulse for spesific combination
                if command = '1' and previous_command = '0' then 
                    pulse <= '1';
                    
                -- Deassert for every other combination.
                else
                    pulse <= '0';
                    
                end if;
                
                previous_command <= command;
                
            end if;
        end if;
    end process;
end Behavioral;

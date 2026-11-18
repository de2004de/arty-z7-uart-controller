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


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity TX is
    Port (
        clk          :in    std_logic;
        tick         :in    std_logic;
        rst          :in    std_logic;
        tx_start     :in    std_logic;
        data_in      :in    std_logic_vector (7 downto 0);
        tx_out       :out   std_logic;
        busy         :out   std_logic;
        tx_done      :out   std_logic
    );
end TX;

architecture Behavioral of TX is
    signal bit_timer    :integer range 0 to 15 := 0;    -- counting x16 samples per bit
    signal counter      :integer range 0 to 7 := 0;     -- counter for the data bits
    signal tx_reg       :std_logic_vector(7 downto 0) := (others => '0');
    type state_type is(idle,data,stop,finish_stop);
    signal state:state_type:= idle;

begin
    process(clk)
    begin
        if rising_edge(clk) then
            tx_done  <= '0'; 
            
            if rst = '1' then
                state     <= IDLE;
                busy      <= '0';
                tx_done   <= '0';
                tx_out    <= '1';
                bit_timer <= 0;
                counter   <= 0;
                tx_reg    <= (others => '0');  
            
            else         
                case state is 
                    when idle =>
                        -- reset the timers before starting
                        busy      <= '0';
                        tx_out    <= '1';
                        
                        if tx_start = '1' then
                            tx_reg <= data_in;
                            busy   <= '1';
                            tx_out    <= '0';
                            counter   <= 0;
                            bit_timer <= 0;
                            state  <= data;
                        end if;
                        
                    when data =>
                        if tick = '1' then
                            if bit_timer = 15 then
                                tx_out <= tx_reg(counter); -- condition after 7 data bits
                                
                                if counter = 7 then 
                                    bit_timer <= 0;
                                    counter   <= 0;
                                    state     <= stop;
                                else
                                    bit_timer <= 0;
                                    counter   <= counter + 1;
                                end if;
                            else
                                bit_timer <= bit_timer + 1;
                            end if;
                        end if;
                        
                    when stop =>
                        -- The final data bit is still being transmitted.
                        if tick = '1' then
                            if bit_timer = 15 then
                                tx_out    <= '1';  -- Begin the stop bit
                                bit_timer <= 0;
                                state     <= finish_stop;
                            else
                                bit_timer <= bit_timer + 1;
                            end if;
                        end if;
                    
                    when finish_stop =>
                        -- Keep tx_out high for a full stop-bit period.
                        if tick = '1' then
                            if bit_timer = 15 then
                                bit_timer <= 0;
                                busy      <= '0';
                                tx_done   <= '1';
                                state     <= idle;
                            else
                                bit_timer <= bit_timer + 1;
                            end if;
                        end if;
                end case;
            end if;
        end if;
    end process;
end Behavioral;

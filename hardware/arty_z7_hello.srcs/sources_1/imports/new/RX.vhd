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

entity RX is
    Port ( 
        clk          :in    std_logic;
        tick         :in    std_logic;
        s_data       :in    std_logic;
        rst          :in    std_logic;
        f_error      :out   std_logic := '0';
        rx_done      :out   std_logic := '0';
        rx_data      :out   std_logic_vector (7 downto 0) := "00000000"
);
end RX;

architecture Behavioral of RX is
    signal counter               :integer range 0 to 7 := 0;     -- counter for the data bits
    signal bit_timer             :integer range 0 to 15 := 0;    -- counting x16 samples per bit
    signal rx_reg                :std_logic_vector (7 downto 0);
    signal sync1,sync2,sync2_d   :std_logic;

    
    type state_type is(idle,start,data,stop);
    signal state:state_type:= idle;

begin
    process(clk)
    begin    
        if rising_edge(clk) then
            rx_done      <= '0';
            f_error      <= '0';
            
            -- 3-stage synchronizer
            sync1   <= s_data;
            sync2   <= sync1;
            sync2_d <= sync2;
            
            if rst = '1' then
                state     <= idle;
                counter   <= 0;
                bit_timer <= 0;
            
                rx_reg    <= (others => '0');
                rx_data   <= (others => '0');
            
                sync1     <= '1';
                sync2     <= '1';
                sync2_d   <= '1';
            else
            
                case state is 
                    -- detect the falling edge
                    when idle =>
                        -- reset the timers before starting
                        counter <= 0;
                        bit_timer <= 0;
                        if (sync2_d = '1' and sync2 = '0') then
                            state <= start;
                        end if;
                    
                    -- start counting towards valid start bit
                    when start => 
                        if tick = '1' then
                            if sync2 = '0' then
                                if bit_timer = 7 then 
                                -- confirm still low in middle of bit
                                    counter <= 0;
                                    bit_timer <= 0;
                                    state <= data;
                                else
                                    bit_timer <= bit_timer + 1;
                                end if;
                            else
                                state <= idle; -- false start
                            end if;
                        end if;
                    
                    -- sample 7 data bits
                    when data => 
                        if tick = '1' then 
                            if bit_timer = 15 then
                                rx_reg(counter) <= sync2;
                                -- condition after 7 data bits
                                if counter = 7 then 
                                    bit_timer <= 0;
                                    state <= stop;
                                else
                                    bit_timer <= 0;
                                    counter <= counter + 1;
                                end if;
                            else
                                bit_timer <= bit_timer + 1;
                            end if;
                        end if;
                    
                    -- detecting stop bit
                    when stop => 
                        if tick = '1' then
                            if bit_timer = 15 then
                                if sync2 /= '1' then
                                    f_error <= '1';
                                else
                                    rx_data <= rx_reg;
                                    rx_done <= '1';
                                end if;
                    
                                counter <= 0;
                                bit_timer <= 0;
                                state <= idle;
                    
                            else
                                bit_timer <= bit_timer + 1;
                            end if;
                        end if;
                end case;
            end if;
        end if;            
    end process;
end architecture;
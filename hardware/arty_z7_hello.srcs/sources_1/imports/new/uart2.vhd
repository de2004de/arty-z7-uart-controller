----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 11/01/2026 12:54:07 PM
-- Design Name: 
-- Module Name: uart2 - Behavioral
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

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity uart2 is
    port(
        clk         :in    std_logic;
        serial_in   :in    std_logic;
        serial_out  :out   std_logic
        
    );
end uart2;

architecture Behavioral of uart2 is
    signal tick         :std_logic;
    signal f_error      :std_logic;
    signal rx_done      :std_logic;
    signal p_data       :std_logic_vector (7 downto 0);
    signal busy         :std_logic;
    signal tx_done      :std_logic;
    signal sig          :std_logic;
    signal rst          :std_logic := '0'; 

    -- baud rate generator
    component uart_baud is
        port(
            clk  :in    std_logic;
            tick :out   std_logic
        );
    end component;
    
    -- rx component
    component RX is
        Port ( 
            clk          :in    std_logic;
            tick         :in    std_logic;
            s_data       :in    std_logic;
            f_error      :out   std_logic;
            rx_done      :out   std_logic;
            rx_data      :out   std_logic_vector (7 downto 0)
        );
    end component;
    
    -- tx component
    component TX is
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
    end component;
    
    begin
    -- map the baud generator
    u1: uart_baud port map(
        clk  => clk,
        tick => tick
        );
       
    -- map the rx   
    u2: RX port map(
        clk     => clk,
        tick    => tick,
        s_data  => serial_in,
        f_error => f_error,
        rx_done => sig,
        rx_data => p_data
        );
    
    u3: TX port map(
        clk       => clk,
        tick      => tick,
        rst       => rst,
        tx_start  => sig,
        data_in   => p_data,
        tx_out    => serial_out,
        busy      => busy,
        tx_done   => tx_done
    );
    
end Behavioral;
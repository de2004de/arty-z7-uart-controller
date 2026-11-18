----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 11/09/2026 04:38:13 PM
-- Design Name: 
-- Module Name: uart_loopback_core - Behavioral
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

entity uart_loopback_core is
    Port ( 
           clk      : in  STD_LOGIC;
           rst      : in  STD_LOGIC;
           tx_start : in  STD_LOGIC;
           tx_data  : in  STD_LOGIC_VECTOR (7 downto 0);
           tx_busy  : out STD_LOGIC;
           tx_done  : out STD_LOGIC;
           rx_data  : out STD_LOGIC_VECTOR (7 downto 0);
           rx_done  : out STD_LOGIC;
           rx_error : out STD_LOGIC
    );
end uart_loopback_core;

architecture Behavioral of uart_loopback_core is
    signal tick   : std_logic;
    signal serial : std_logic;

    -- baud rate generator
    component uart_baud is
        port(
            clk  :in  std_logic;
            rst  :in  std_logic;
            tick :out std_logic
        );
    end component;
    
    -- rx component
    component RX is
        Port ( 
            clk          :in    std_logic;
            tick         :in    std_logic;
            s_data       :in    std_logic;
            rst          :in    std_logic;
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
        rst  => rst,
        tick => tick
        );
       
    -- map the rx   
    u2: RX port map(
        clk     => clk,
        tick    => tick,
        s_data  => serial,
        rst     => rst,
        f_error => rx_error,
        rx_done => rx_done,
        rx_data => rx_data
        );
    
    u3: TX port map(
        clk       => clk,
        tick      => tick,
        rst       => rst,
        tx_start  => tx_start,
        data_in   => tx_data,
        tx_out    => serial,
        busy      => tx_busy,
        tx_done   => tx_done
    );

end Behavioral;

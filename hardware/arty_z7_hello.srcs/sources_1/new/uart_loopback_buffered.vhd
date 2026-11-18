----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 11/09/2026 08:42:54 PM
-- Design Name: 
-- Module Name: uart_loopback_buffered - Behavioral
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

entity uart_loopback_buffered is
    Port ( 
        clk        : in  STD_LOGIC;
        rst        : in  STD_LOGIC;
        tx_start   : in  STD_LOGIC;
        tx_data    : in  STD_LOGIC_VECTOR (7 downto 0);
        fifo_read  : in  STD_LOGIC;
        fifo_data  : out STD_LOGIC_VECTOR (7 downto 0);
        fifo_empty : out STD_LOGIC;
        fifo_full  : out STD_LOGIC;
        tx_busy    : out STD_LOGIC;
        tx_done    : out STD_LOGIC;
        rx_error   : out STD_LOGIC
        

    );
end uart_loopback_buffered;

architecture Behavioral of uart_loopback_buffered is
    signal data_out_rx : STD_LOGIC_VECTOR (7 downto 0);
    signal write_buffer: STD_LOGIC;
    
    -- the main uart component
    component uart_loopback_core is
        port(
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
    end component;
    
    -- fifo component
    component FIFO is
        port(
            clk        : in  std_logic;
            rst        : in  std_logic;
            read_pin   : in  std_logic;
            write_pin  : in  std_logic;
            data_in    : in  std_logic_vector(7 downto 0);
            data_out   : out std_logic_vector(7 downto 0);
            full       : out std_logic;
            empty      : out std_logic
        );
    end component;

begin
    -- map the main uart component
    u1: uart_loopback_core port map(
           clk      => clk,
           rst      => rst,
           tx_start => tx_start,
           tx_data  => tx_data,
           tx_busy  => tx_busy,
           tx_done  => tx_done,
           rx_data  => data_out_rx,
           rx_done  => write_buffer,
           rx_error => rx_error
    );
        
    -- map the fifo buffer
    u2: FIFO port map(
            clk       => clk,
            rst       => rst,
            read_pin  => fifo_read,
            write_pin => write_buffer,
            data_in   => data_out_rx,
            data_out  => fifo_data,
            full      => fifo_full,
            empty     => fifo_empty
        );

end Behavioral;

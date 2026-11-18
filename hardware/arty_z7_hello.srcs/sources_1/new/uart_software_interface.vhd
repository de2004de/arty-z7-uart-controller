----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 11/10/2026 08:14:52 PM
-- Design Name: 
-- Module Name: uart_software_interface - Behavioral
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

entity uart_software_interface is
    Port ( 
        clk            : in  STD_LOGIC;
        rst            : in  STD_LOGIC;
        tx_command     : in  STD_LOGIC;
        read_command   : in  STD_LOGIC;
        tx_data        : in  STD_LOGIC_VECTOR (7 downto 0);
        fifo_data      : out STD_LOGIC_VECTOR (7 downto 0);
        fifo_empty     : out STD_LOGIC;
        fifo_full      : out STD_LOGIC;
        tx_busy        : out STD_LOGIC;
        tx_done        : out STD_LOGIC;
        rx_error       : out STD_LOGIC;
        tx_complete    : out STD_LOGIC;
        read_complete  : out STD_LOGIC
    );
end uart_software_interface;

architecture Behavioral of uart_software_interface is
    signal tx_start_pulse      : std_logic;
    signal fifo_read_pulse     : std_logic;
    signal tx_done_internal    : std_logic;
    signal fifo_empty_internal : std_logic;
    signal read_pending        : std_logic;
    
    component command_pulse is
        Port ( 
            clk     : in  STD_LOGIC;
            rst     : in  STD_LOGIC;
            command : in  STD_LOGIC;
            pulse   : out STD_LOGIC
        );
    end component;
    
    component uart_loopback_buffered is
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
    end component;

begin
    u_tx_command : command_pulse port map(
        clk     => clk,
        rst     => rst,
        command => tx_command,
        pulse   => tx_start_pulse
    );
    
    u_read_command : command_pulse port map(
        clk     => clk,
        rst     => rst,
        command => read_command,
        pulse   => fifo_read_pulse
    );
    
    uart_buffered : uart_loopback_buffered port map(
        clk         => clk,
        rst         => rst,
        tx_start    => tx_start_pulse,
        tx_data     => tx_data,
        fifo_read   => fifo_read_pulse,
        fifo_data   => fifo_data,
        fifo_empty  => fifo_empty_internal,
        fifo_full   => fifo_full,
        tx_busy     => tx_busy,
        tx_done     => tx_done_internal,
        rx_error    => rx_error
    );
    
    tx_done <= tx_done_internal;
    fifo_empty <= fifo_empty_internal;
    
    -- transmition complete handshake
    process(clk)
    begin
        if rising_edge (clk) then
            if (rst = '1') then 
                tx_complete <= '0';
            elsif tx_command = '0' then 
                tx_complete <= '0';
            elsif tx_done_internal = '1' then
                tx_complete <= '1';
            end if;
        end if;
    end process;
    
    -- read fifo handshake
    process(clk)
    begin
        if rising_edge (clk) then
            if (rst = '1') then 
                read_pending  <= '0';
                read_complete <= '0';            
            else
                if (fifo_read_pulse = '1' and fifo_empty_internal = '0') then
                    read_pending <= '1';
                else    
                    read_pending <= '0';
                end if;
            
                -- completion decision
                if (read_command = '0') then
                    read_complete <= '0';
                elsif read_pending = '1' then 
                    read_complete <= '1';    
                end if;
            end if;
        end if;
    end process;
end Behavioral;

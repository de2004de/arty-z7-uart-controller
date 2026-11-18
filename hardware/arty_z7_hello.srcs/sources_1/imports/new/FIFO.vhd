library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity FIFO is
    Port ( 
        clk        : in  std_logic;
        rst        : in  std_logic;
        read_pin   : in  std_logic;
        write_pin  : in  std_logic;
        data_in    : in  std_logic_vector(7 downto 0);
        data_out   : out std_logic_vector(7 downto 0);
        full       : out std_logic;
        empty      : out std_logic
    );
end FIFO;

architecture Behavioral of FIFO is

    constant DEPTH : integer := 32;
    type storage is array (0 to DEPTH-1) of std_logic_vector(7 downto 0);
    signal store : storage;

    signal write_point : integer range 0 to DEPTH-1 := 0;
    signal read_point  : integer range 0 to DEPTH-1 := 0;
    signal data_count  : integer range 0 to DEPTH := 0;

begin
    -- FIFO STATUS
    full  <= '1' when data_count = DEPTH else '0';
    empty <= '1' when data_count = 0     else '0';


    process(clk)
        variable do_write   : boolean;
        variable do_read    : boolean;
        variable next_count : integer range 0 to DEPTH;

    begin
        if rising_edge(clk) then
            -- RESET
            if rst = '1' then
                write_point <= 0;
                read_point  <= 0;
                data_count  <= 0;
                data_out    <= (others => '0');

            else
                -- Decide whether requested operations are allowed
                do_write := (write_pin = '1') and (data_count < DEPTH);
                do_read := (read_pin = '1') and (data_count > 0);
                next_count := data_count;

                -- WRITE
                if do_write then
                    store(write_point) <= data_in;

                    if write_point = DEPTH-1 then
                        write_point <= 0;
                    else
                        write_point <= write_point + 1;
                    end if;
                end if;

                -- READ
                if do_read then
                    data_out <= store(read_point);

                    if read_point = DEPTH-1 then
                        read_point <= 0;
                    else
                        read_point <= read_point + 1;
                    end if;
                end if;

                -- UPDATE NUMBER OF BYTES STORED
                if do_write and not do_read then
                    next_count := data_count + 1;
                elsif do_read and not do_write then
                    next_count := data_count - 1;
                end if;

                data_count <= next_count;

            end if;
        end if;
    end process;

end Behavioral;
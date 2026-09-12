library ieee;
use ieee.std_logic_1164.all;

-- Terasic DE1 (Cyclone II EP2C20F484C7) top-level wrapper for the
-- validated searchx core. Pure board glue: no additional logic.
-- rtl/searchx.vhd is instantiated unmodified.
entity search_de1_top is
    port (
        CLOCK_50 : in  std_logic;                     -- 50 MHz board clock
        KEY0     : in  std_logic;                      -- KEY(0), active-low reset
        SW       : in  std_logic_vector(7 downto 0);    -- SW(7 downto 0), searched value
        SW9      : in  std_logic;                       -- SW(9), debut
        LEDR     : out std_logic_vector(3 downto 0);     -- LEDR(3 downto 0), result index
        LEDG     : out std_logic_vector(1 downto 0)      -- LEDG(0)=fini, LEDG(1)=non_exist
    );
end entity search_de1_top;

architecture A1 of search_de1_top is
begin

    U_SEARCH : entity work.searchx(A1)
        port map (
            clk       => CLOCK_50,
            reset     => KEY0,
            debut     => SW9,
            Xinput    => SW,
            index     => LEDR,
            fini      => LEDG(0),
            non_exist => LEDG(1)
        );

end architecture A1;

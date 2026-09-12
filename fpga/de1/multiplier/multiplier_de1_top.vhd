library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Terasic DE1 (Cyclone II EP2C20F484C7) top-level wrapper for the
-- validated mult_shift_add core. Board-only glue: operand latching from
-- switches and a 7-segment decoder for the result. rtl/mult_shift_add.vhd
-- is instantiated unmodified.
entity multiplier_de1_top is
    port (
        CLOCK_50 : in  std_logic;                     -- 50 MHz board clock
        KEY0     : in  std_logic;                      -- KEY(0), active-low reset
        SW       : in  std_logic_vector(9 downto 0);    -- SW(7:0)=operand data,
                                                         -- SW(8)=A/B select, SW(9)=start
        LEDG0    : out std_logic;                       -- LEDG(0) = fin
        LEDR     : out std_logic_vector(9 downto 0);     -- switch reflection
        HEX0     : out std_logic_vector(6 downto 0);
        HEX1     : out std_logic_vector(6 downto 0);
        HEX2     : out std_logic_vector(6 downto 0);
        HEX3     : out std_logic_vector(6 downto 0)
    );
end entity multiplier_de1_top;

architecture A1 of multiplier_de1_top is

    signal reset_n : std_logic;
    signal start_sig : std_logic;
    signal fin_sig  : std_logic;

    signal A_user : std_logic_vector(7 downto 0) := (others => '0');
    signal B_user : std_logic_vector(7 downto 0) := (others => '0');
    signal R_mult : std_logic_vector(15 downto 0);

    -- 7-segment decoder, DE1 segments active low.
    function hex7seg(x : std_logic_vector(3 downto 0)) return std_logic_vector is
        variable s : std_logic_vector(6 downto 0);
    begin
        case x is
            when "0000" => s := "1000000"; -- 0
            when "0001" => s := "1111001"; -- 1
            when "0010" => s := "0100100"; -- 2
            when "0011" => s := "0110000"; -- 3
            when "0100" => s := "0011001"; -- 4
            when "0101" => s := "0010010"; -- 5
            when "0110" => s := "0000010"; -- 6
            when "0111" => s := "1111000"; -- 7
            when "1000" => s := "0000000"; -- 8
            when "1001" => s := "0010000"; -- 9
            when "1010" => s := "0001000"; -- A
            when "1011" => s := "0000011"; -- b
            when "1100" => s := "1000110"; -- C
            when "1101" => s := "0100001"; -- d
            when "1110" => s := "0000110"; -- E
            when others => s := "0001110"; -- F
        end case;
        return s;
    end function;

begin

    reset_n   <= KEY0;    -- KEY(0), active low
    start_sig <= SW(9);

    -- Operand latching: SW(8)=0 loads A, SW(8)=1 loads B, only while start=0.
    process (CLOCK_50, reset_n)
    begin
        if reset_n = '0' then
            A_user <= (others => '0');
            B_user <= (others => '0');
        elsif rising_edge(CLOCK_50) then
            if start_sig = '0' then
                if SW(8) = '0' then
                    A_user <= SW(7 downto 0);
                else
                    B_user <= SW(7 downto 0);
                end if;
            end if;
        end if;
    end process;

    U_MULT : entity work.mult_shift_add(A1)
        port map (
            clk   => CLOCK_50,
            reset => reset_n,
            start => start_sig,
            A_in  => A_user,
            B_in  => B_user,
            R_out => R_mult,
            fin   => fin_sig
        );

    LEDG0 <= fin_sig;
    LEDR  <= SW;

    HEX0 <= hex7seg(R_mult(3 downto 0));
    HEX1 <= hex7seg(R_mult(7 downto 4));
    HEX2 <= hex7seg(R_mult(11 downto 8));
    HEX3 <= hex7seg(R_mult(15 downto 12));

end architecture A1;

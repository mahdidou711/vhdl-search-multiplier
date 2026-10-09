library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity mult_shift_add is
    port(
        clk   : in  std_logic;
        reset : in  std_logic; -- Reset asynchrone actif a '0'.
        start : in  std_logic;
        A_in  : in  std_logic_vector(7 downto 0);
        B_in  : in  std_logic_vector(7 downto 0);
        R_out : out std_logic_vector(15 downto 0);
        fin   : out std_logic
    );
end mult_shift_add;

architecture A1 of mult_shift_add is

    type etat_t is (IDLE, CALC, DONE);
    signal etat : etat_t := IDLE;

    signal A_reg : std_logic_vector(7 downto 0) := (others => '0');
    signal B_reg : std_logic_vector(7 downto 0) := (others => '0');
    signal R_reg : std_logic_vector(15 downto 0) := (others => '0');

    signal i_reg   : integer range 0 to 8 := 0;
    signal fin_reg : std_logic := '0';

begin

    R_out <= R_reg;
    fin   <= fin_reg;

    process(clk, reset)
        variable sum9     : unsigned(8 downto 0);
        variable concat17 : unsigned(16 downto 0); -- pour gérer la retenue avant décalage
        variable Rh_u     : unsigned(7 downto 0);
        variable Rl_u     : unsigned(7 downto 0);
        variable A_u      : unsigned(7 downto 0);
    begin
        if reset = '0' then
            etat    <= IDLE;
            A_reg   <= (others => '0');
            B_reg   <= (others => '0');
            R_reg   <= (others => '0');
            i_reg   <= 0;
            fin_reg <= '0';

        elsif rising_edge(clk) then
            case etat is

                when IDLE =>
                    fin_reg <= '0';

                    if start = '1' then
                        A_reg <= A_in;
                        B_reg <= B_in;
                        R_reg <= (others => '0');
                        i_reg <= 0;
                        etat  <= CALC;
                    end if;

                when CALC =>
                    -- Préparation des parties hautes/basses de R
                    Rh_u := unsigned(R_reg(15 downto 8));
                    Rl_u := unsigned(R_reg(7 downto 0));
                    A_u  := unsigned(A_reg);

                    -- Addition conditionnelle selon b0 = B_reg(0)
                    if B_reg(0) = '1' then
                        sum9 := ('0' & Rh_u) + ('0' & A_u);
                    else
                        sum9 := ('0' & Rh_u);
                    end if;

                    -- Construire (carry + Rh + Rl) puis décalage à droite
                    concat17 := sum9 & Rl_u;
                    R_reg <= std_logic_vector(concat17(16 downto 1)); -- shift right de 1

                    -- Décalage du multiplicateur B
                    B_reg <= '0' & B_reg(7 downto 1);

                    -- Compteur d'itérations
                    if i_reg = 7 then
                        etat    <= DONE;
                        fin_reg <= '1';
                    else
                        i_reg <= i_reg + 1;
                    end if;

                when DONE =>
                    -- garder le résultat tant que start reste à 1
                    if start = '0' then
                        fin_reg <= '0';
                        etat    <= IDLE;
                    end if;

            end case;
        end if;
    end process;

end A1;
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.all;

entity TopLevel is
    Port (
        CLOCK_50 : in  std_logic;
        KEY      : in  std_logic_vector (3 downto 0);
        SW       : in  std_logic_vector (9 downto 0);
        LEDG     : out std_logic_vector (7 downto 0);
        LEDR     : out std_logic_vector (9 downto 0);
        HEX0     : out std_logic_vector (6 downto 0);
        HEX1     : out std_logic_vector (6 downto 0);
        HEX2     : out std_logic_vector (6 downto 0);
        HEX3     : out std_logic_vector (6 downto 0)
    );
end TopLevel;

architecture A1 of TopLevel is

    -- Signaux interface multiplieur
    signal reset_n   : std_logic;
    signal start_sig : std_logic;
    signal fin_sig   : std_logic;

    signal A_user    : std_logic_vector(7 downto 0) := (others => '0');
    signal B_user    : std_logic_vector(7 downto 0) := (others => '0');
    signal R_mult    : std_logic_vector(15 downto 0);

    -- Décodeur 7 segments (DE1 : segments actifs à 0)
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

    -- Commandes carte
    reset_n   <= KEY(0); -- KEY0 actif à 0 sur DE1 (appui = reset)
    start_sig <= SW(9);

    --------------------------------------------------------------------
    -- Mémorisation des opérandes A / B depuis SW[7..0]
    -- SW(8)=0 -> on charge A ; SW(8)=1 -> on charge B
    -- (seulement quand start=0 pour éviter de modifier pendant le calcul)
    --------------------------------------------------------------------
    process(CLOCK_50, reset_n)
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

    --------------------------------------------------------------------
    -- Instanciation du multiplieur
    --------------------------------------------------------------------
    U_MULT : entity work.mult_shift_add
        port map (
            clk   => CLOCK_50,
            reset => reset_n,
            start => start_sig,
            A_in  => A_user,
            B_in  => B_user,
            R_out => R_mult,
            fin   => fin_sig
        );

    --------------------------------------------------------------------
    -- Affichages / LEDs
    --------------------------------------------------------------------
    -- LED de fin (demande de l'énoncé)
    LEDG(0) <= fin_sig;

    -- LEDs de debug (optionnel, utile)
    LEDG(1) <= SW(8);      -- sélection registre A/B
    LEDG(2) <= SW(9);      -- start
    LEDG(7 downto 3) <= (others => '0');

    -- Afficher les switches d'entrée pour vérifier visuellement
    LEDR(7 downto 0) <= SW(7 downto 0);
    LEDR(8) <= SW(8);
    LEDR(9) <= SW(9);

    -- Résultat sur 4 afficheurs HEX (16 bits)
    HEX0 <= hex7seg(R_mult(3 downto 0));
    HEX1 <= hex7seg(R_mult(7 downto 4));
    HEX2 <= hex7seg(R_mult(11 downto 8));
    HEX3 <= hex7seg(R_mult(15 downto 12));

end A1;
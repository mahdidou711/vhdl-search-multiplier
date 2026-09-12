Library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity searchx is
  port (
      clk,reset,debut : in std_logic;
      Xinput : in std_logic_vector( 7 downto 0); -- code a rechercher
      index : out std_logic_vector(3 downto 0);  -- position valide si non_existe est faux
      fini, non_exist : out std_logic  -- fin recherche     code non existant   
  );
end searchx;

architecture A1 of searchx is

    -- Tableau de 16 valeurs (8 bits)
    type tab_t is array (0 to 15) of std_logic_vector(7 downto 0);
    constant TAB : tab_t := (
        x"10", x"22", x"35", x"48",
        x"59", x"6A", x"7B", x"8C",
        x"9D", x"AE", x"BF", x"C1",
        x"D2", x"E3", x"F4", x"55"
    );
    -- x"22" est present pour que ton script commandes.do puisse le trouver

    -- Automate
    type etat_t is (IDLE, SEARCH, DONE);
    signal etat : etat_t := IDLE;

    -- Indice de parcours du tableau
    signal i_reg : integer range 0 to 15 := 0;

    -- Registres internes pour les sorties
    signal index_reg     : std_logic_vector(3 downto 0) := (others => '0');
    signal fini_reg      : std_logic := '0';
    signal non_exist_reg : std_logic := '0';

begin

    -- Affectation des sorties
    index     <= index_reg;
    fini      <= fini_reg;
    non_exist <= non_exist_reg;

    process (clk, reset)
    begin

        -- Reset actif à 0 (compatible avec ton commandes.do)
        if reset = '0' then
            etat          <= IDLE;
            i_reg         <= 0;
            index_reg     <= (others => '0');
            fini_reg      <= '0';
            non_exist_reg <= '0';

        elsif rising_edge(clk) then

            case etat is

                when IDLE =>
                    -- Etat d'attente : on attend debut = 1
                    fini_reg      <= '0';
                    non_exist_reg <= '0';
                    index_reg     <= (others => '0');

                    if debut = '1' then
                        i_reg <= 0;
                        etat  <= SEARCH;
                    end if;

                when SEARCH =>
                    -- Comparaison sequentielle : TAB(i_reg) avec Xinput
                    if TAB(i_reg) = Xinput then
                        index_reg     <= std_logic_vector(to_unsigned(i_reg, 4));
                        fini_reg      <= '1';
                        non_exist_reg <= '0';
                        etat          <= DONE;

                    else
                        if i_reg = 15 then
                            -- Fin du tableau : valeur non trouvee
                            index_reg     <= (others => '0');
                            fini_reg      <= '1';
                            non_exist_reg <= '1';
                            etat          <= DONE;
                        else
                            i_reg <= i_reg + 1;
                        end if;
                    end if;

                when DONE =>
                    -- On garde le resultat tant que debut reste a 1
                    -- (pratique pour visualiser en simulation / LEDs)
                    if debut = '0' then
                        fini_reg      <= '0';
                        non_exist_reg <= '0';
                        etat          <= IDLE;
                    end if;

            end case;
        end if;

    end process;
end A1;
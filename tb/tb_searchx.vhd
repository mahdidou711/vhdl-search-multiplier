library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_searchx is
end tb_searchx;

architecture test of tb_searchx is
    constant CLK_PERIOD : time := 10 ns;

    type tab_t is array (0 to 15) of std_logic_vector(7 downto 0);
    constant TAB : tab_t := (
        x"10", x"22", x"35", x"48",
        x"59", x"6A", x"7B", x"8C",
        x"9D", x"AE", x"BF", x"C1",
        x"D2", x"E3", x"F4", x"55"
    );

    signal clk           : std_logic := '0';
    signal reset         : std_logic := '0';
    signal debut         : std_logic := '0';
    signal Xinput        : std_logic_vector(7 downto 0) := (others => '0');
    signal index         : std_logic_vector(3 downto 0);
    signal fini          : std_logic;
    signal non_exist     : std_logic;
    signal clock_running : boolean := true;

    function is_binary(value : std_logic_vector) return boolean is
    begin
        for bit_index in value'range loop
            if value(bit_index) /= '0' and value(bit_index) /= '1' then
                return false;
            end if;
        end loop;
        return true;
    end function;
begin
    dut : entity work.searchx(A1)
        port map (
            clk       => clk,
            reset     => reset,
            debut     => debut,
            Xinput    => Xinput,
            index     => index,
            fini      => fini,
            non_exist => non_exist
        );

    clock_generator : process
    begin
        while clock_running loop
            clk <= '0';
            wait for CLK_PERIOD / 2;
            clk <= '1';
            wait for CLK_PERIOD / 2;
        end loop;
        wait;
    end process;

    stimulus : process
        procedure tick is
        begin
            wait until rising_edge(clk);
            -- Allow the registered value and the concurrent output assignment
            -- in the DUT to propagate through their delta cycles.
            wait for 1 ns;
        end procedure;

        procedure check_index(
            constant expected_index : in integer;
            constant context        : in string
        ) is
        begin
            assert is_binary(index)
                report context & ": index contains a non-binary value"
                severity error;
            assert index = std_logic_vector(to_unsigned(expected_index,
                                                         index'length))
                report context & ": unexpected index" severity error;
        end procedure;

        procedure check_idle_outputs(constant context : in string) is
        begin
            assert fini = '0'
                report context & ": fini should be low" severity error;
            assert non_exist = '0'
                report context & ": non_exist should be low" severity error;
            check_index(0, context);
        end procedure;

        procedure check_done_release(
            constant expected_retained_index : in integer;
            constant context                 : in string
        ) is
        begin
            assert fini = '0'
                report context & ": fini should be low" severity error;
            assert non_exist = '0'
                report context & ": non_exist should be low" severity error;
            -- TEST DE CARACTERISATION: the DONE branch does not clear index.
            -- Its last result remains visible until the following IDLE edge.
            check_index(expected_retained_index, context);
        end procedure;

        procedure run_search(
            constant value                : in std_logic_vector(7 downto 0);
            constant expected_index       : in integer;
            constant expected_non_exist   : in std_logic;
            constant expected_comparisons : in positive
        ) is
        begin
            -- TEST DE CONFORMITE: one-cycle debut pulse and exact latency.
            Xinput <= value;
            debut  <= '1';
            tick;                       -- IDLE accepts debut.
            assert fini = '0'
                report "fini asserted on the acceptance edge" severity error;
            debut <= '0';

            for comparison in 1 to expected_comparisons loop
                tick;                   -- One SEARCH comparison.
                if comparison < expected_comparisons then
                    assert fini = '0'
                        report "search completed too early" severity error;
                else
                    assert fini = '1'
                        report "search did not complete at expected latency"
                        severity error;
                    assert non_exist = expected_non_exist
                        report "unexpected non_exist value" severity error;
                    check_index(expected_index, "completed search");
                end if;
            end loop;

            tick;                       -- DONE sees debut low, then returns IDLE.
            check_done_release(expected_index, "after search release");
        end procedure;
    begin
        -----------------------------------------------------------------------
        -- TEST DE CONFORMITE: asynchronous active-low reset.
        -----------------------------------------------------------------------
        wait for 2 ns;
        check_idle_outputs("during initial reset");
        reset <= '1';
        tick;
        check_idle_outputs("after reset release");

        -----------------------------------------------------------------------
        -- TEST DE CONFORMITE: all 16 ROM positions and their exact latency.
        -- The table contains no duplicate, so each expected index is also the
        -- first occurrence. A value at index k needs k+1 comparison cycles
        -- after the front that accepts debut.
        -----------------------------------------------------------------------
        for k in TAB'range loop
            run_search(TAB(k), k, '0', k + 1);
        end loop;

        -----------------------------------------------------------------------
        -- TEST DE CONFORMITE: absent values. The baseline returns index zero
        -- and asserts non_exist after all 16 comparisons.
        -----------------------------------------------------------------------
        run_search(x"00", 0, '1', 16);
        run_search(x"21", 0, '1', 16);
        run_search(x"54", 0, '1', 16);
        run_search(x"FF", 0, '1', 16);

        -----------------------------------------------------------------------
        -- TEST DE CONFORMITE: one-cycle debut pulses were exercised above.
        -- TEST DE CARACTERISATION: DONE is held while debut stays high, and a
        -- new search is accepted only after debut has returned low.
        -----------------------------------------------------------------------
        Xinput <= x"22";
        debut  <= '1';
        tick;                           -- Acceptance.
        tick;                           -- Compare index 0.
        assert fini = '0' report "held-debut search completed too early"
            severity error;
        tick;                           -- Compare index 1, enter DONE.
        assert fini = '1' and non_exist = '0'
            report "held-debut result is incorrect" severity error;
        check_index(1, "held-debut result");

        for hold_cycle in 1 to 3 loop
            tick;
            assert fini = '1' and non_exist = '0'
                report "DONE result changed while debut remained high"
                severity error;
            check_index(1, "held-debut DONE");
        end loop;

        Xinput <= x"35";               -- Must not relaunch while still DONE.
        tick;
        assert fini = '1'
            report "search relaunched without releasing debut" severity error;
        check_index(1, "held-debut relaunch attempt");
        debut <= '0';
        tick;
        check_done_release(1, "after held debut release");
        run_search(x"35", 2, '0', 3);  -- Relaunch without a new reset.

        -----------------------------------------------------------------------
        -- TEST DE CONFORMITE: reset asserted asynchronously during SEARCH.
        -----------------------------------------------------------------------
        Xinput <= x"F4";
        debut  <= '1';
        tick;
        debut <= '0';
        tick;
        tick;
        tick;
        reset <= '0';
        wait for 1 ns;
        check_idle_outputs("asynchronous reset during search");
        reset <= '1';
        tick;
        check_idle_outputs("reset recovery during search");
        run_search(x"59", 4, '0', 5);

        -----------------------------------------------------------------------
        -- TEST DE CONFORMITE: Xinput must be captured EXACTLY on the rising
        -- edge where state = IDLE and debut = '1' (the acceptance edge), not
        -- kept live during SEARCH and not captured one cycle late on the
        -- first SEARCH edge.
        --
        -- Chronology:
        --   1. Xinput <= A (F4).
        --   2. debut  <= '1'.
        --   3. tick() lands exactly on the acceptance edge (state=IDLE,
        --      debut='1' sampled there); X_reg must capture F4 on this edge.
        --   4. Immediately after that edge (1 ns later, inside the same
        --      10 ns clock period) but strictly before the first SEARCH
        --      rising edge, Xinput is changed to B (8C).
        --   5. The transaction continues for 15 comparison cycles.
        --   6/7. A DUT that still reads Xinput live during SEARCH, or that
        --      captures Xinput one cycle late (on the first SEARCH edge,
        --      by which time Xinput already reads 8C), would match B at
        --      TAB(7)=8C and assert fini after only 8 comparisons: this is
        --      caught by the fini='0' assertions below for comparisons 1..14.
        --   8. A correct DUT ignores the post-acceptance change and completes
        --      with A at index 14, non_exist='0'.
        -----------------------------------------------------------------------
        Xinput <= x"F4";                -- A
        debut  <= '1';
        tick;                           -- Acceptance edge: state=IDLE, debut='1'.
                                         -- X_reg must capture F4 here.
        debut  <= '0';
        Xinput <= x"8C";                -- B: applied after the acceptance edge,
                                         -- before the first SEARCH rising edge.
        assert fini = '0'
            report "capture-timing setup completed unexpectedly" severity error;
        check_index(0, "capture-timing acceptance edge");

        for comparison in 1 to 15 loop
            tick;                       -- SEARCH comparisons for the captured A.
            if comparison < 15 then
                assert fini = '0'
                    report "capture-timing search completed too early " &
                           "(likely matched B=8C instead of retaining A=F4)"
                    severity error;
            else
                assert fini = '1' and non_exist = '0'
                    report "capture-timing search did not retain A" severity error;
                check_index(14, "capture-timing completed search");
            end if;
        end loop;
        tick;
        check_done_release(14, "after capture-timing test");

        assert false report "tb_searchx: reset PASS" severity note;
        assert false report "tb_searchx: 16 ROM positions PASS" severity note;
        assert false report "tb_searchx: absent values PASS" severity note;
        assert false report "tb_searchx: latency PASS" severity note;
        assert false report "tb_searchx: relaunch/debut protocol PASS" severity note;
        assert false report "tb_searchx: reset during search PASS" severity note;
        assert false report "tb_searchx: Xinput capture-timing contract PASS"
            severity note;
        assert false report "tb_searchx PASS" severity note;

        clock_running <= false;
        wait for CLK_PERIOD;
        wait;
    end process;
end test;

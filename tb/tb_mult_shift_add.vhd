library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_mult_shift_add is
end tb_mult_shift_add;

architecture test of tb_mult_shift_add is
    constant CLK_PERIOD : time := 10 ns;

    signal clk           : std_logic := '0';
    signal reset         : std_logic := '0';
    signal start         : std_logic := '0';
    signal A_in          : std_logic_vector(7 downto 0) := (others => '0');
    signal B_in          : std_logic_vector(7 downto 0) := (others => '0');
    signal R_out         : std_logic_vector(15 downto 0);
    signal fin           : std_logic;
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
    dut : entity work.mult_shift_add(A1)
        port map (
            clk   => clk,
            reset => reset,
            start => start,
            A_in  => A_in,
            B_in  => B_in,
            R_out => R_out,
            fin   => fin
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
        variable checked    : integer := 0;
        variable mismatches : integer := 0;

        procedure tick is
        begin
            wait until rising_edge(clk);
            wait for 1 ns;
        end procedure;

        procedure check_result(
            constant expected_product : in integer;
            constant context          : in string
        ) is
        begin
            assert is_binary(R_out)
                report context & ": R_out contains a non-binary value"
                severity error;
            assert R_out = std_logic_vector(to_unsigned(expected_product,
                                                         R_out'length))
                report context & ": unexpected product" severity error;
        end procedure;

        procedure run_product(
            constant a : in integer;
            constant b : in integer
        ) is
            constant expected : integer := a * b;
        begin
            -- TEST DE CONFORMITE: inputs are accepted in IDLE, followed by
            -- exactly eight CALC edges. fin and the final result appear on the
            -- eighth CALC edge.
            A_in  <= std_logic_vector(to_unsigned(a, 8));
            B_in  <= std_logic_vector(to_unsigned(b, 8));
            start <= '1';
            tick;                       -- Acceptance edge.
            assert fin = '0'
                report "fin asserted on multiplication acceptance" severity error;
            start <= '0';

            for iteration in 1 to 8 loop
                tick;
                if iteration < 8 then
                    assert fin = '0'
                        report "fin asserted before eight iterations"
                        severity error;
                else
                    assert is_binary(R_out)
                        report "R_out contains a non-binary value for " &
                               integer'image(a) & " x " & integer'image(b)
                        severity error;
                    if R_out /= std_logic_vector(to_unsigned(expected,
                                                              R_out'length)) then
                        mismatches := mismatches + 1;
                    end if;
                    assert R_out = std_logic_vector(to_unsigned(expected,
                                                                 R_out'length))
                        report "product mismatch for " & integer'image(a) &
                               " x " & integer'image(b)
                        severity error;
                    assert fin = '1'
                        report "fin missing after eight iterations"
                        severity error;
                end if;
            end loop;

            tick;                       -- DONE sees start low and clears fin.
            assert fin = '0'
                report "fin did not clear after one-cycle start" severity error;
            check_result(expected, "result after leaving DONE");
        end procedure;
    begin
        -----------------------------------------------------------------------
        -- TEST DE CONFORMITE: asynchronous active-low reset.
        -----------------------------------------------------------------------
        wait for 2 ns;
        assert fin = '0' report "unexpected fin during reset" severity error;
        check_result(0, "outputs during reset");
        reset <= '1';
        tick;
        assert fin = '0' report "fin high after reset release" severity error;

        -----------------------------------------------------------------------
        -- TEST DE CONFORMITE: directed arithmetic cases.
        -----------------------------------------------------------------------
        run_product(0, 0);
        run_product(0, 1);
        run_product(1, 0);
        run_product(1, 1);
        run_product(13, 11);
        run_product(255, 255);
        run_product(255, 1);
        run_product(1, 255);
        run_product(128, 2);
        run_product(2, 128);
        run_product(16#55#, 16#AA#);
        run_product(16#AA#, 16#55#);

        -----------------------------------------------------------------------
        -- TEST DE CARACTERISATION: fin and R_out remain stable in DONE while
        -- start stays high. A new operand pair is ignored until start is low.
        -----------------------------------------------------------------------
        A_in  <= std_logic_vector(to_unsigned(13, 8));
        B_in  <= std_logic_vector(to_unsigned(11, 8));
        start <= '1';
        tick;
        for iteration in 1 to 8 loop
            tick;
            if iteration < 8 then
                assert fin = '0' report "held-start fin asserted too early"
                    severity error;
            end if;
        end loop;
        assert fin = '1' report "held-start fin is missing" severity error;
        check_result(143, "held-start product");

        A_in <= x"01";
        B_in <= x"01";
        for hold_cycle in 1 to 3 loop
            tick;
            assert fin = '1'
                report "DONE changed or relaunched while start stayed high"
                severity error;
            check_result(143, "held-start DONE");
        end loop;
        start <= '0';
        tick;
        assert fin = '0' report "held-start fin did not clear" severity error;
        check_result(143, "held-start release");
        run_product(1, 1);              -- Relaunch after returning start low.

        -----------------------------------------------------------------------
        -- TEST DE CONFORMITE: A_in and B_in are captured exactly on the start
        -- acceptance edge. Change both signals immediately after that edge and
        -- before the first CALC edge. A mutant sampling on first CALC therefore
        -- computes 0 instead of 55 hexadecimal times AA hexadecimal.
        -----------------------------------------------------------------------
        A_in  <= x"55";
        B_in  <= x"AA";
        start <= '1';
        tick;                           -- Acceptance edge.
        start <= '0';
        A_in <= x"00";
        B_in <= x"00";
        for iteration in 1 to 8 loop
            tick;
            if iteration < 8 then
                assert fin = '0' report "input-change test finished early"
                    severity error;
            end if;
        end loop;
        assert fin = '1' report "capture-edge test fin is missing" severity error;
        check_result(16#55# * 16#AA#, "capture on start edge");
        tick;
        assert fin = '0' severity error;

        -----------------------------------------------------------------------
        -- TEST DE CARACTERISATION: a start pulse during CALC is ignored.
        -----------------------------------------------------------------------
        A_in  <= std_logic_vector(to_unsigned(128, 8));
        B_in  <= std_logic_vector(to_unsigned(2, 8));
        start <= '1';
        tick;
        start <= '0';
        tick;
        tick;
        A_in  <= x"01";
        B_in  <= x"01";
        start <= '1';
        tick;                           -- Third CALC iteration, not a launch.
        start <= '0';
        for iteration in 4 to 8 loop
            tick;
            if iteration < 8 then
                assert fin = '0' report "CALC start-pulse test finished early"
                    severity error;
            end if;
        end loop;
        assert fin = '1' report "CALC start-pulse fin is missing" severity error;
        check_result(256, "start during CALC");
        tick;
        assert fin = '0' severity error;

        -----------------------------------------------------------------------
        -- TEST DE CONFORMITE: asynchronous reset during CALC clears state and
        -- permits a subsequent clean multiplication.
        -----------------------------------------------------------------------
        A_in  <= x"FF";
        B_in  <= x"FF";
        start <= '1';
        tick;
        start <= '0';
        tick;
        tick;
        tick;
        reset <= '0';
        wait for 1 ns;
        assert fin = '0' report "reset during CALC did not clear fin"
            severity error;
        check_result(0, "reset during CALC");
        reset <= '1';
        tick;
        assert fin = '0' report "unexpected fin after CALC reset release"
            severity error;
        check_result(0, "state after CALC reset release");
        run_product(7, 9);

        -----------------------------------------------------------------------
        -- TEST DE CONFORMITE: exhaustive unsigned 8-bit multiplication.
        -----------------------------------------------------------------------
        checked := 0;
        mismatches := 0;
        for a in 0 to 255 loop
            for b in 0 to 255 loop
                run_product(a, b);
                checked := checked + 1;
            end loop;
        end loop;

        assert checked = 65536 report "exhaustive campaign count is incorrect"
            severity error;
        assert mismatches = 0 report "exhaustive campaign found mismatches"
            severity error;

        assert false report "tb_mult_shift_add: directed products PASS"
            severity note;
        assert false report "tb_mult_shift_add: start/DONE protocol PASS"
            severity note;
        assert false report "tb_mult_shift_add: result stability PASS"
            severity note;
        assert false report "tb_mult_shift_add: captured A/B PASS" severity note;
        assert false report "tb_mult_shift_add: start during CALC PASS"
            severity note;
        assert false report "tb_mult_shift_add: reset during CALC PASS"
            severity note;
        assert false report "tb_mult_shift_add: exact eight-iteration latency PASS"
            severity note;
        assert false report "65536 products checked" severity note;
        assert false report "0 mismatches" severity note;
        assert false report "tb_mult_shift_add PASS" severity note;

        clock_running <= false;
        wait for CLK_PERIOD;
        wait;
    end process;
end test;

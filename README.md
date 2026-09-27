# Sequential VHDL Search and Iterative Multiplier

> **Quick overview** — VHDL · sequential FSM design · iterative arithmetic · cycle-exact GHDL verification · **65,536** multiplier combinations · GitHub Actions CI · Terasic DE1 hardware implementation

Two small, self-contained VHDL sequential designs, each verified with an
exhaustive or near-exhaustive GHDL testbench and implemented on a Terasic DE1
(Cyclone II) FPGA:

1. **`searchx`** (a sequential search engine over a fixed 16 × 8-bit table).
2. **`mult_shift_add`** (an unsigned 8 × 8 iterative shift-add multiplier
   producing a 16-bit result).

Both designs originated from university FPGA coursework and were later
cleaned up, given deterministic-latency testbenches, and packaged here as a
small, reproducible portfolio project.

The `mult_shift_add` core (`rtl/mult_shift_add.vhd`) was originally written by Omar, a fellow student on the assignment, and is published here with his permission. The `searchx` core and the verification, FPGA integration, CI, and documentation added for this repository are Mehdi Bouama's work.

## Shared architectural theme

- Simple FSM-controlled sequential processing (`IDLE` / working state /
  `DONE`), no combinational shortcuts.
- Deterministic, cycle-exact latency: the number of clock edges between
  transaction acceptance and completion is fixed and verified.
- Transaction inputs are registered ("captured") at acceptance time, so
  later changes on the input ports cannot corrupt an in-flight transaction.
- Small, single-core, FPGA-oriented implementations: no bus protocol, no
  pipelining.

---

## `searchx`: sequential search core

RTL: [`rtl/searchx.vhd`](rtl/searchx.vhd)

### Interface

| Port | Direction | Width | Meaning |
|---|---|---|---|
| `clk` | in | 1 | clock |
| `reset` | in | 1 | **asynchronous, active-low** reset |
| `debut` | in | 1 | transaction request ("start") |
| `Xinput` | in | 8 | value to search for |
| `index` | out | 4 | position of the match (valid when `non_exist = '0'`) |
| `fini` | out | 1 | transaction complete |
| `non_exist` | out | 1 | `'1'` if `Xinput` is not present in the table |

### Behavior

- FSM: `IDLE → SEARCH → DONE`.
- The table (`TAB`) is a fixed, hard-coded array of 16 distinct 8-bit
  constants.
- `Xinput` is captured into an internal register on the exact rising edge
  where the FSM is in `IDLE` and `debut = '1'` (the *acceptance edge*).
  Every comparison during `SEARCH` uses that captured value, not the live
  `Xinput` port, so changing `Xinput` after acceptance cannot affect an
  in-flight search.
- Exactly one table entry is compared per clock cycle while in `SEARCH`.
- `DONE` holds `fini` / `non_exist` / `index` stable as long as `debut`
  stays high; the FSM only returns to `IDLE` once `debut` is released low,
  which also rearms it for the next transaction.

### Latency (verified, not estimated)

- A value present at table index `k` completes after exactly `k + 1`
  `SEARCH` comparison edges following the acceptance edge.
- A value absent from the table completes after exactly 16 comparison
  edges (`non_exist = '1'`).

---

## `mult_shift_add`: 8×8 iterative shift-add multiplier

RTL: [`rtl/mult_shift_add.vhd`](rtl/mult_shift_add.vhd)

### Interface

| Port | Direction | Width | Meaning |
|---|---|---|---|
| `clk` | in | 1 | clock |
| `reset` | in | 1 | asynchronous, active-low reset |
| `start` | in | 1 | transaction request |
| `A_in` | in | 8 | unsigned multiplicand |
| `B_in` | in | 8 | unsigned multiplier |
| `R_out` | out | 16 | unsigned product |
| `fin` | out | 1 | transaction complete |

### Behavior

- FSM: `IDLE → CALC → DONE`.
- `A_in` and `B_in` are captured into internal registers on the cycle the
  transaction starts (`start = '1'` while in `IDLE`); later changes on
  `A_in` / `B_in` during `CALC` do not affect the accepted transaction.
- Classic shift-add algorithm: each `CALC` cycle conditionally adds the
  captured `A` to the running partial-product high half (only if the
  current multiplier LSB is `'1'`), then shifts the combined
  carry/high/low register right by one bit, and shifts the captured
  multiplier right by one bit.
- Exactly **8** `CALC` iterations, matching the 8-bit multiplier width.
- `DONE` holds `R_out` / `fin` stable until `start` is released low, then
  returns to `IDLE`.

This is an unsigned, fixed-width, non-pipelined design; there is no signed
multiplication and no per-cycle throughput beyond one product every 10
clock cycles (1 acceptance + 8 `CALC` + return to `IDLE`).

---

## Verification

Canonical command:

```bash
./sim/ghdl/run_tests.sh
```

This script is the single entry point for all local and CI verification.
It is hermetic (runs in a `mktemp` build directory, cleaned up on exit) and
uses VHDL-93 throughout.

### `searchx` testbench (`tb/tb_searchx.vhd`)

- Asynchronous reset behavior.
- All 16 table positions, each with its exact expected latency.
- Several values absent from the table (full 16-comparison latency).
- One-cycle `debut` pulses and a held `debut` (result held in `DONE`,
  no accidental relaunch).
- Transaction restart (rearming) after `debut` is released.
- Asynchronous reset asserted mid-`SEARCH`.
- A capture-timing test that changes `Xinput` to a different, colliding
  table value immediately after the acceptance edge (before the first
  `SEARCH` edge) and confirms the core still completes on the *captured*
  value; this specifically catches both "still reads `Xinput` live" and
  "captures one cycle late" implementation bugs.
- Non-binary / meta-value (`'X'`/`'U'`/...) protection on relevant checks.

### `mult_shift_add` testbench (`tb/tb_mult_shift_add.vhd`)

- Directed products, exact 8-iteration latency, and `start`/`DONE`
  protocol checks.
- Operand capture: `A_in`/`B_in` changes during `CALC` do not affect the
  in-flight product.
- Asynchronous reset asserted mid-`CALC`.
- **Exhaustive verification**: all 256 × 256 = 65,536 unsigned operand
  combinations are simulated, with zero mismatches against the expected
  product in the validated suite.

### FPGA wrapper checks

In addition to the two testbenches above, `run_tests.sh` also:

- **analyzes** both DE1 top-level wrappers (`search_de1_top`,
  `multiplier_de1_top`) with `ghdl -a`, catching syntax errors, entity/port
  mismatches, and missing RTL dependencies;
- **synthesis-checks** both wrappers with `ghdl --synth`, confirming they
  elaborate and synthesize at the GHDL level (this is not a substitute for
  Quartus Analysis & Synthesis; see [Validation status](#validation-status)).

---

## FPGA implementation / Terasic DE1

- **Target board:** Terasic DE1
- **FPGA:** Altera/Intel Cyclone II, `EP2C20F484C7`
- **Clock:** `CLOCK_50`, 50 MHz nominal, constrained in each `.sdc` as a
  20 ns TimeQuest clock

Two independent, minimal Quartus projects, each instantiating exactly one
RTL core through a thin board-glue wrapper (no shared top-level, no unused
peripherals):

### Multiplier: [`fpga/de1/multiplier/`](fpga/de1/multiplier/)

| Board control | Function |
|---|---|
| `SW(7:0)` | operand data |
| `SW(8)` | select operand A (`0`) / B (`1`) |
| `SW(9)` | start |
| `KEY0` | active-low reset |
| `LEDG0` | `fin` |
| `LEDR(9:0)` | reflects `SW`, for visual feedback |
| `HEX0..HEX3` | 16-bit product, hexadecimal |

Usage: while `SW(9)`/start is low, the operand register selected by
`SW(8)` (A when low, B when high) continuously loads from `SW(7:0)` on
every clock edge. So the procedure is: set the desired byte on `SW(7:0)`,
set `SW(8)` to pick A or B, keep `SW(9)` low while doing so, then raise
`SW(9)` to launch the multiplication with the two most recently loaded
values.

### Search: [`fpga/de1/search/`](fpga/de1/search/)

| Board control | Function |
|---|---|
| `SW(7:0)` | search value |
| `SW9` | `debut` |
| `KEY0` | active-low reset |
| `LEDR(3:0)` | result index |
| `LEDG(0)` | `fini` |
| `LEDG(1)` | `non_exist` |

Every Cyclone II pin not explicitly assigned in either project is reserved
as a tri-stated input (`RESERVE_ALL_UNUSED_PINS "AS INPUT TRI-STATED"`),
avoiding Quartus's default of driving unassigned pins low.

## Validation status

**Automated locally by `run_tests.sh` / GHDL:**

- VHDL-93 analysis of every RTL, testbench, and FPGA wrapper source file.
- Both RTL testbenches, including the exhaustive 65,536-combination
  multiplier sweep.
- FPGA wrapper analysis (`ghdl -a`) for both DE1 top-levels.
- FPGA wrapper synthesisability checks (`ghdl --synth`) for both DE1
  top-levels.

**Statically reviewed (not GHDL, checked by inspection):**

- QPF/QSF/SDC structure.
- Source paths declared in each `.qsf`.
- Top-level entity names.
- Target device/family declarations.
- `CLOCK_50` naming consistency across `.qsf`/`.sdc`/VHDL.
- Pin-assignment consistency and absence of duplicate physical pin
  assignments.

GHDL does not read or validate `.qsf`/`.qpf` files; the checks in this
second group were done by direct inspection of the project files, not by
any tool run.

**GitHub Actions CI:**

- GitHub Actions CI has been executed successfully on the public repository.
  The workflow runs the same GHDL verification suite on every push and pull
  request targeting `main`.

**Hardware validation:**

- Both designs were implemented and programmed on a physical Terasic DE1 board.
- Functional behavior was tested using the board switches, LEDs, and seven-segment displays.
- The current repository does not claim a verified maximum clock frequency and does not include a current TimeQuest timing-closure report.

The `.sdc` files declare a 20 ns (50 MHz) clock constraint for TimeQuest.
The hardware implementation is validated functionally; no timing-margin or
Fmax claim is made here.

---

## Build / run

Requirements:

- Bash
- [GHDL](https://ghdl.github.io/ghdl/) with VHDL-93 and synthesis
  (`--synth`) support (the project has been locally validated with
  GHDL 4.1.0)

Run the full verification suite:

```bash
./sim/ghdl/run_tests.sh
```

A GitHub Actions workflow ([`.github/workflows/ghdl.yml`](.github/workflows/ghdl.yml))
runs the same script on every push and pull request targeting `main`.

For FPGA implementation, each `.qpf` in `fpga/de1/` can be opened with a
Quartus release supporting the Cyclone II family. The designs were implemented
and tested on a Terasic DE1 during project development; the automated checks in
this repository complement that hardware validation.

---

## Repository structure

```
rtl/                        validated RTL cores (searchx, mult_shift_add)
tb/                          GHDL testbenches for both cores
sim/ghdl/                    run_tests.sh (canonical verification entry point)
fpga/de1/multiplier/         DE1 top-level + Quartus project for the multiplier
fpga/de1/search/             DE1 top-level + Quartus project for the search core
.github/workflows/           CI: runs run_tests.sh on push/PR to main
```

## Design scope / non-goals

This project intentionally stays small:

- fixed-width 8×8 unsigned multiplier (no signed support, no generic
  width);
- fixed 16-entry search table (not a parameterizable memory);
- no bus protocol (AXI/Wishbone/ready-valid) around either core;
- no pipelining: one transaction completes before the next is accepted;
- no debounce or synchronizer logic on the DE1 wrappers (switches are
  assumed manually operated and stable for the board interface).

These are deliberate scope choices for a small, readable reference design,
not omissions.

## License

No explicit open-source license is currently provided for this
repository. Parts of the FPGA integration layer trace back to
vendor-supplied Terasic DE1 project material; that provenance has not been
fully resolved, so no license terms are asserted here yet.

#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)"
BUILD_DIR="$(mktemp -d "${TMPDIR:-/tmp}/vhdl-search-multiplier-ghdl.XXXXXX")"

cleanup() {
    rm -rf -- "$BUILD_DIR"
}
trap cleanup EXIT

cd "$BUILD_DIR"

echo "GHDL version: $(ghdl --version | head -n 1)"
echo "VHDL standard: 93"

ghdl -a --std=93 "$REPO_ROOT/rtl/searchx.vhd"
ghdl -a --std=93 "$REPO_ROOT/rtl/mult_shift_add.vhd"
ghdl -a --std=93 "$REPO_ROOT/tb/tb_searchx.vhd"
ghdl -a --std=93 "$REPO_ROOT/tb/tb_mult_shift_add.vhd"

ghdl -e --std=93 tb_searchx
ghdl -e --std=93 tb_mult_shift_add

echo "Running tb_searchx"
ghdl -r --std=93 tb_searchx --assert-level=error

echo "Running tb_mult_shift_add"
ghdl -r --std=93 tb_mult_shift_add --assert-level=error

# Source-level analysis of the DE1 FPGA wrappers (syntax, entity/port
# matching, RTL dependencies). No simulation: these are board glue only.
echo "Analyzing FPGA wrapper: search_de1_top"
ghdl -a --std=93 "$REPO_ROOT/fpga/de1/search/search_de1_top.vhd"

echo "Analyzing FPGA wrapper: multiplier_de1_top"
ghdl -a --std=93 "$REPO_ROOT/fpga/de1/multiplier/multiplier_de1_top.vhd"

# Synthesisability checks for the DE1 FPGA wrappers. This is a GHDL-level
# elaboration/synthesis check, not a substitute for Quartus compilation.
# The generated netlist is discarded (stdout only, never written to disk).
echo "Synthesis-checking FPGA wrapper: search_de1_top"
ghdl --synth --std=93 \
    "$REPO_ROOT/rtl/searchx.vhd" \
    "$REPO_ROOT/fpga/de1/search/search_de1_top.vhd" \
    -e search_de1_top > /dev/null

echo "Synthesis-checking FPGA wrapper: multiplier_de1_top"
ghdl --synth --std=93 \
    "$REPO_ROOT/rtl/mult_shift_add.vhd" \
    "$REPO_ROOT/fpga/de1/multiplier/multiplier_de1_top.vhd" \
    -e multiplier_de1_top > /dev/null

echo "All GHDL tests passed"

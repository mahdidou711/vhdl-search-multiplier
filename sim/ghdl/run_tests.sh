#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)"
BUILD_DIR="$(mktemp -d "${TMPDIR:-/tmp}/tp1-vhdl-ghdl.XXXXXX")"

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

echo "All GHDL tests passed"

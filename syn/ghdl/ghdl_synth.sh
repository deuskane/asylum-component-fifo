#!/bin/bash
#-----------------------------------------------------------------------------
# Title      : Synthesis check of fifo_sync with ghdl --synth (post_run hook)
# Project    : Asylum
#-----------------------------------------------------------------------------
# File       : ghdl_synth.sh
# Author     : mrosiere
#-----------------------------------------------------------------------------
# Description: post_run hook of the lint_ghdl_synth target (cwd = fusesoc
#              work_root, after the run step : the ghdl -m of edalize has
#              analyzed (-Wall) and elaborated the top in library asylum).
#              Synthesizes the top for each configuration below. Writes
#              synth_<config>.vhd (netlist) and synth_<config>.log, prints
#              the warnings of each configuration, fails if a synthesis
#              fails or infers a latch.
#-----------------------------------------------------------------------------
# Copyright (c) 2026
#-----------------------------------------------------------------------------
# Revisions  :
# Date        Version  Author   Description
# 2026-10-20  1.0      mrosiere Created
#-----------------------------------------------------------------------------

TOP=fifo_sync
TOP_LIB="--work=asylum --workdir=./asylum"
GHDL_OPT="--std=08 -Wall -P./asylum"

# name : generics
CONFIGS=(
    "default           : "
    "depth1_read_async : -gDEPTH=1"
    "depth1_read_sync  : -gDEPTH=1 -gSYNC_READ=true"
    "depth8_read_async : -gDEPTH=8"
    "depth8_read_sync  : -gDEPTH=8 -gSYNC_READ=true"
)

nb_fail=0
for config in "${CONFIGS[@]}"; do
    name=$(echo "${config%%:*}" | tr -d ' ')
    generics=${config#*:}

    # shellcheck disable=SC2086
    ghdl --synth $GHDL_OPT $TOP_LIB $generics $TOP > "synth_${name}.vhd" 2> "synth_${name}.log"
    rc=$?

    if [ $rc -ne 0 ]; then
        status="FAIL (ghdl rc=$rc)"
    elif grep -qi "latch" "synth_${name}.log"; then
        status="FAIL (latch)"
    else
        status="PASS"
    fi
    [ "$status" = "PASS" ] || nb_fail=$((nb_fail + 1))
    nb_warn=$(grep -ci "warning" "synth_${name}.log")

    printf "ghdl --synth %-18s : %s (%d warnings)\n" "$name" "$status" "$nb_warn"
    if [ "$status" != "PASS" ]; then
        sed 's/^/    /' "synth_${name}.log"
    elif [ "$nb_warn" -ne 0 ]; then
        grep -i "warning" "synth_${name}.log" | sed 's/^/    /'
    fi
done

if [ $nb_fail -ne 0 ]; then
    echo "lint_ghdl_synth : FAIL ($nb_fail / ${#CONFIGS[@]} configurations)"
    exit 1
fi
echo "lint_ghdl_synth : PASS (${#CONFIGS[@]} configurations)"

<!--
  README MODEL (common to every Asylum IP, keep the same headings)
  ----------------------------------------------------------------
  Regenerate from the sources, never from the previous README text alone:
    hdl/*.vhd (entities, generics, ports), hdl/csr/*.hjson (register map),
    <IP>.core (VLNV, targets, depends), mk/targets.txt, sim/, syn/, esw/.
  Sections, in this order:
    badges / title + one-line pitch / Overview / Features / Block Diagram /
    Getting Started / Hardware Interfaces / Configuration / Resources /
    Theory of Operation / Registers / Programmer's Guide /
    Design Verification / Dependencies and Related IPs / License
  Rules:
    - English, short and factual: every statement backed by the sources.
    - No VLNV line: the version badge shows it.
    - Badges: first line version, license; second line CI, lint, sim, syn.
    - Block diagram and FSM: pages Overview and FSM of doc/<NAME>.drawio, exported to
      doc/<NAME>-Overview.png and doc/<NAME>-FSM.png (make -C doc).
    - Timing diagrams: WaveDrom source doc/<NAME>-<what>.json, rendered
      doc/<NAME>-<what>.svg (make -C doc), shown as images.
    - No CPU named (OpenBlaze, PicoBlaze, RISC-V) outside the CPU and SoC IPs.
    - Registers: link to the generated hdl/csr/<X>_csr.md, never copy the tables.
    - Tables: Configuration = Name|Type|Default|Description,
      Hardware Interfaces = Name|Direction|Type|Description, grouped by interface.
    - A section with nothing to say is one line ("This IP has no
      software-visible registers."), never removed.
-->
[![Version](https://img.shields.io/github/v/tag/deuskane/asylum-component-fifo?filter=asylum-component-fifo-*&label=version&color=blue)](https://github.com/deuskane/asylum-component-fifo/tags)
[![License](https://img.shields.io/github/license/deuskane/asylum-component-fifo)](LICENSE)

[![CI](https://github.com/deuskane/asylum-component-fifo/actions/workflows/ci.yml/badge.svg)](https://github.com/deuskane/asylum-component-fifo/actions/workflows/ci.yml)
[![lint](https://img.shields.io/endpoint?url=https%3A%2F%2Fraw.githubusercontent.com%2Fdeuskane%2Fasylum-component-fifo%2Fbadges%2Flint.json)](https://github.com/deuskane/asylum-component-fifo/actions/workflows/ci.yml)
[![sim](https://img.shields.io/endpoint?url=https%3A%2F%2Fraw.githubusercontent.com%2Fdeuskane%2Fasylum-component-fifo%2Fbadges%2Fsim.json)](https://github.com/deuskane/asylum-component-fifo/actions/workflows/ci.yml)
[![syn](https://img.shields.io/endpoint?url=https%3A%2F%2Fraw.githubusercontent.com%2Fdeuskane%2Fasylum-component-fifo%2Fbadges%2Fsyn.json)](https://github.com/deuskane/asylum-component-fifo/actions/workflows/ci.yml)

# FIFO

**A small, readable synchronous FIFO in VHDL: AXI-Stream valid / ready on both sides, full / empty flags and fill levels, asynchronous or synchronous RAM read.**

Part of the [Asylum project](https://github.com/deuskane/asylum-project), a collection of small IP cores, written to be read and learned from.

## Table of Contents

1. [Overview](#overview)
2. [Features](#features)
3. [Block Diagram](#block-diagram)
4. [Getting Started](#getting-started)
5. [Hardware Interfaces](#hardware-interfaces)
6. [Configuration](#configuration)
7. [Resources](#resources)
8. [Theory of Operation](#theory-of-operation)
9. [Registers](#registers)
10. [Programmer's Guide](#programmers-guide)
11. [Design Verification](#design-verification)
12. [Dependencies and Related IPs](#dependencies-and-related-ips)
13. [License](#license)

## Overview

`fifo_sync` is the FIFO of the Asylum IPs: a producer writes words on one side, a consumer reads them in the same order on the other side, both in the same clock domain. The words are stored in a `ram_1r1w` (core `asylum:component:ram`) addressed by a write pointer and a read pointer. Each pointer has one extra bit, the lap bit, which tells a full FIFO from an empty one.

Both sides use AXI-Stream-like valid / ready handshakes, and both see the full / empty flags and a fill level. The `SYNC_READ` generic selects a RAM with an asynchronous read (distributed RAM, flip-flops) or a synchronous read (block RAM friendly), with the same timing on the interfaces.

## Features

- Single clock domain (`clk_i`), asynchronous active-low reset (`arst_b_i`)
- Generic word width (`WIDTH`) and depth (`DEPTH`, a power of 2, 1 included)
- Write side: `s_axis_tvalid_i` / `s_axis_tready_o` / `s_axis_tdata_i`, `s_axis_tready_o = not full`
- Read side: `m_axis_tvalid_o` / `m_axis_tready_i` / `m_axis_tdata_o`, `m_axis_tvalid_o = not empty`; `m_axis_tdata_o` holds the oldest word as long as `m_axis_tvalid_o = 1`
- Full and empty flags on both sides, number of free words (`s_axis_nb_elt_empty_o`) and of stored words (`m_axis_nb_elt_full_o`)
- One write and one read per cycle; a word written is readable in the next cycle
- `SYNC_READ = true`: synchronous RAM read, with an output register for a written word that becomes the head at once
- Simulation only: assertion `nb_elt_full + nb_elt_empty = DEPTH` on every clock edge
- Component declaration in `asylum.fifo_pkg`

## Block Diagram

![Block diagram of fifo_sync](doc/fifo-Overview.png)

- `wptr` and `rptr` are `clog2(DEPTH)+1`-bit counters, incremented on a write handshake (`s_axis_tvalid_i and s_axis_tready_o`) and on a read handshake (`m_axis_tvalid_o and m_axis_tready_i`).
- `ins_RAM` (`ram_1r1w`) is written at `wptr` with `s_axis_tdata_i` on every write handshake.
- The flag logic compares the two pointers: empty, full and the two fill levels.
- `SYNC_READ = true` only: `tdata_r` captures a written word that becomes the head before the RAM can return it, and the output mux selects it.

## Getting Started

The cores of the Asylum IPs are published in the FuseSoC library [asylum-cores](https://github.com/deuskane/asylum-cores) (with the UVVM core used by the testbench):

```bash
pip install fusesoc
fusesoc library add https://github.com/deuskane/asylum-cores
fusesoc run --target sim_fifo_depth8_read_sync_push_pop asylum:component:fifo  # needs GHDL
```

To use the IP in your design, add `asylum:component:fifo` to the `depend` list of your core and instantiate `fifo_sync` (library `asylum`):

```vhdl
library asylum;
use     asylum.fifo_pkg.all;

  ins_fifo : fifo_sync
    generic map
    (WIDTH                 => 16
    ,DEPTH                 => 32
    ,SYNC_READ             => true
    )
    port map
    (clk_i                 => clk
    ,arst_b_i              => arst_b
    ,s_axis_tvalid_i       => producer_valid
    ,s_axis_tready_o       => producer_ready
    ,s_axis_tdata_i        => producer_data    -- std_logic_vector(16-1 downto 0)
    ,s_axis_nb_elt_empty_o => fifo_nb_free     -- std_logic_vector( 6-1 downto 0)
    ,s_axis_full_o         => fifo_full
    ,s_axis_empty_o        => open
    ,m_axis_tvalid_o       => consumer_valid
    ,m_axis_tready_i       => consumer_ready
    ,m_axis_tdata_o        => consumer_data    -- std_logic_vector(16-1 downto 0)
    ,m_axis_nb_elt_full_o  => fifo_nb_used     -- std_logic_vector( 6-1 downto 0)
    ,m_axis_full_o         => open
    ,m_axis_empty_o        => fifo_empty
    );
```

## Hardware Interfaces

Entity `fifo_sync` ([hdl/fifo_sync.vhd](hdl/fifo_sync.vhd)), component in `asylum.fifo_pkg` ([hdl/fifo_pkg.vhd](hdl/fifo_pkg.vhd)).

### Clock and Reset

| Name | Direction | Type | Description |
|------|-----------|------|-------------|
| `clk_i` | in | std_logic | Clock |
| `arst_b_i` | in | std_logic | Asynchronous reset, active low: empties the FIFO (pointers, output register); the RAM content is not reset |

### Write side (AXI-Stream slave)

| Name | Direction | Type | Description |
|------|-----------|------|-------------|
| `s_axis_tvalid_i` | in | std_logic | Write request |
| `s_axis_tready_o` | out | std_logic | FIFO not full: the word is written when `s_axis_tvalid_i = 1` |
| `s_axis_tdata_i` | in | std_logic_vector(WIDTH-1 downto 0) | Word to write |
| `s_axis_nb_elt_empty_o` | out | std_logic_vector(clog2(DEPTH) downto 0) | Number of free words |
| `s_axis_full_o` | out | std_logic | FIFO full |
| `s_axis_empty_o` | out | std_logic | FIFO empty |

### Read side (AXI-Stream master)

| Name | Direction | Type | Description |
|------|-----------|------|-------------|
| `m_axis_tvalid_o` | out | std_logic | FIFO not empty: `m_axis_tdata_o` is the oldest word |
| `m_axis_tready_i` | in | std_logic | Read acknowledge: the word is removed when `m_axis_tvalid_o = 1` |
| `m_axis_tdata_o` | out | std_logic_vector(WIDTH-1 downto 0) | Oldest word, meaningful only when `m_axis_tvalid_o = 1` |
| `m_axis_nb_elt_full_o` | out | std_logic_vector(clog2(DEPTH) downto 0) | Number of stored words |
| `m_axis_full_o` | out | std_logic | FIFO full (same signal as `s_axis_full_o`) |
| `m_axis_empty_o` | out | std_logic | FIFO empty (same signal as `s_axis_empty_o`) |

## Configuration

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `WIDTH` | natural | `8` | Word width in bits |
| `DEPTH` | natural | `4` | Number of words, a power of 2 (the pointers wrap at `2**clog2(DEPTH)`; `ram_1r1w` reports an error in simulation for another value) |
| `SYNC_READ` | boolean | `false` | `false`: asynchronous RAM read; `true`: synchronous RAM read and output register |

## Resources

Figures of the `syn_*` targets (`make nonreg_syn`, see [Targets](#targets)): `fifo_sync` with the generics of each configuration (`WIDTH = 8` in all), synthesized by Yosys and its GHDL plugin; the reports are in the build directory of each target.

| Configuration | LUT¹ | LUTRAM¹ | FF¹ | CARRY4¹ | MUXF7/F8¹ | BRAM¹ | DSP¹ | Area² (µm²) | kGE³ |
|---|---|---|---|---|---|---|---|---|---|
| `syn_default` (`DEPTH` 4, asynchronous read) | 11 | 8 | 6 | 4 | 2 | 0 | 0 | 1570.26 | 0.418 |
| `syn_depth1_read_async` | 6 | 0 | 10 | 0 | 0 | 0 | 0 | 336.57 | 0.090 |
| `syn_depth1_read_sync` | 15 | 0 | 27 | 0 | 0 | 0 | 0 | 1000.96 | 0.267 |
| `syn_depth8_read_async` | 15 | 8 | 8 | 4 | 0 | 0 | 0 | 3017.89 | 0.804 |
| `syn_depth8_read_sync` | 28 | 8 | 25 | 4 | 1 | 0 | 0 | 3739.84 | 0.996 |

¹ Xilinx Artix-7 (LUT6), Yosys 0.33 `synth_xilinx -flatten -noiopad -noclkbuf`, before place and route: every cell of the netlist is counted, Vivado may differ. Identical cells are merged as a vendor tool does (`opt_merge -share_all`): the inverters of an active-low reset net become one; every remaining cell is counted, an `INV` as a `LUT1` (1 to 4 of the LUTs above). With 4 and 8 words the storage is in LUTRAM (two `RAM32M`), not in BRAM; with 1 word it is 8 flip-flops. `SYNC_READ = true` adds the RAM read register, the output register `tdata_r` and its valid bit (`2 x WIDTH + 1` flip-flops).

² SkyWater sky130 `sky130_fd_sc_hd`, typical corner (tt, 25 °C, 1.80 V), Yosys 0.33 `synth` + `dfflibmap` + `abc -liberty`: standard-cell area only, no timing constraint, no buffering, clock tree or placement; the storage becomes flip-flops (no SRAM macro).

³ Area in thousands of NAND2 gate equivalents (`sky130_fd_sc_hd__nand2_1` = 3.7536 µm²).

## Theory of Operation

### Pointers and flags

With `ADDR = clog2(DEPTH)`, `wptr` and `rptr` have `ADDR+1` bits: the `ADDR` low bits address the RAM, the top bit (lap bit) changes each time a pointer wraps.

- `empty = (wptr(ADDR-1:0) = rptr(ADDR-1:0)) and (wptr(ADDR) = rptr(ADDR))`
- `full  = (wptr(ADDR-1:0) = rptr(ADDR-1:0)) and (wptr(ADDR) /= rptr(ADDR))`
- `nb_elt_full  = (msb_ne & wptr(ADDR-1:0)) - (0 & rptr(ADDR-1:0))`, `msb_ne = wptr(ADDR) xor rptr(ADDR)`
- `nb_elt_empty = (msb_eq & rptr(ADDR-1:0)) - (0 & wptr(ADDR-1:0))`, `msb_eq = not msb_ne`

With `DEPTH = 1` there is no address bit: the addresses are always equal (`gen_ptr_lsb_eq_depth1`) and only the lap bit tells empty from full.

The flags and fill levels are combinational functions of the two pointer registers: they change on the clock edge of a handshake. `s_axis_tready_o` only depends on `full`: a full FIFO refuses a write even when a word is read in the same cycle.

### Handshakes

![Write and read handshakes](doc/fifo-handshake.svg)

A word written on a clock edge is presented on the read side from the next cycle; the consumer can hold `m_axis_tready_i` low as long as it wants, `m_axis_tdata_o` keeps the oldest word. A write and a read can happen in the same cycle at every fill level but full (read only) and empty (write only).

### SYNC_READ

- `SYNC_READ = false`: `m_axis_tdata_o` is the asynchronous RAM read at `rptr`.
- `SYNC_READ = true`: the RAM read port is enabled by `m_axis_tready_i` and addressed by `rptr+1`, so that after a read the next word is already in the RAM read register. Two cases need the output register `tdata_r` instead, loaded with `s_axis_tdata_i`: a write in an empty FIFO, and a write and a read in the same cycle with one word stored (the RAM is then read at the address being written and would return its old content). `m_axis_tdata_o` is `tdata_r` while its valid bit is set (cleared by the next read), else the RAM read register.

The interface timing is the same for both values. Versions before 1.2.1 returned a stale word in the second case, and with `DEPTH = 1` looked non-empty after reset.

### Reset

`arst_b_i` resets the pointers and the output register: the FIFO is empty at once, without clock edge. The RAM is not reset, so `m_axis_tdata_o` is undefined (`'U'` in simulation) until the first word is written.

## Registers

This IP has no software-visible registers.

## Programmer's Guide

This IP has no registers: it is not visible to software.

## Design Verification

### Testbench

| File | DUT | Description |
|------|-----|-------------|
| [sim/fifo_sync/tb_fifo_sync.vhd](sim/fifo_sync/tb_fifo_sync.vhd) | `fifo_sync` (`WIDTH = 8`) | Self-checking UVVM testbench, generics `TESTS_LIST` (scenarios, see below), `DEPTH` and `SYNC_READ` (of the DUT). The scenarios use two kinds of helpers of [tb_fifo_sync_bfm_pkg](sim/fifo_sync/tb_fifo_sync_bfm_pkg.vhd): word transfers with the UVVM AXI-Stream BFM (`push`, `pop`), and cycle accurate transfers (`cycle`): write and read requests driven on the falling edge, then on every cycle the 8 flags and fill levels and the oldest word (when not empty) checked against a model of the FIFO. Scenarios in `tb_fifo_sync_<name>_pkg`, names and dispatch in [tb_fifo_sync_tests_pkg](sim/fifo_sync/tb_fifo_sync_tests_pkg.vhd) |

### Scenarios (`TESTS_LIST`)

The scenarios are chosen at run time with the generic `TESTS_LIST`: names separated by `,` without space (`push_pop,random,push_pop`), a name may be repeated. The sequencer first checks every name (an unknown name is a `TB_ERROR` before any scenario runs), then for each scenario drives a reset pulse with the handshakes inactive, logs `TEST <i>/<N> : <name>` and runs it: each scenario starts from reset. Each scenario writes its own words, so that a word left in the RAM by a previous scenario never equals an expected word. The empty list (default) only compiles and elaborates the testbench. The list is parsed and its names checked with `list_length` / `list_item` / `list_contains` of `asylum.string_pkg` (`asylum:utils:pkg` >= 1.10.0).

Checks counted as the `=> OK` lines of the log, reference configuration `DEPTH = 8`, `SYNC_READ = true` (same counts with `SYNC_READ = false`):

| Name | Checks | Description |
|------|--------|-------------|
| `reset_values` | 32 | Flags and fill levels after reset (empty), unchanged by 4 idle cycles |
| `write_read` | 5 | `min(5, DEPTH)` words written, then read in order (BFM) |
| `fill_drain` | 24 | `DEPTH` words written: flags and fill levels of a full FIFO; read in order, then empty again (BFM) |
| `alternate` | 16 | `2 x DEPTH` pairs of one write and one read (BFM) |
| `half_full` | 12 | `DEPTH/2` words written, then `DEPTH` write / read pairs, then the last words read (BFM); needs `DEPTH >= 2` |
| `overflow` | 187 | FIFO filled, 4 more writes refused (`s_axis_tready_o = 0`, oldest word unchanged), drain: the words are read unchanged (cycle by cycle) |
| `underflow` | 57 | Empty FIFO: 4 reads refused (`m_axis_tvalid_o = 0`, nothing removed), then one word written and read (cycle by cycle) |
| `push_pop` | 2341 | A write and a read in the same cycle at every fill level from 0 to `DEPTH`, from reset: one isolated, then 4 back to back, then drain; each level reached by writes from empty, then (below `DEPTH`) by one read from the level above (`SYNC_READ`: bypass with the output register empty) (cycle by cycle) |
| `random` | 10647 | 1200 cycles of random writes and reads in 4 profiles (balanced, toward full, toward empty, busy), then drain (cycle by cycle) |
| `async_reset` | 131 | FIFO full, reset asserted between two clock edges: empty at once; the words written after the reset are read back (cycle by cycle) |

The testbench was validated with 28 RTL mutants of `fifo_sync.vhd` (flags, pointers, handshakes, RAM addresses, `SYNC_READ` output register and bypass, reset), each run scenario by scenario in the 4 configurations: every mutant is killed except one equivalent mutant (RAM read enable on the read handshake instead of `m_axis_tready_i`).

### Targets

| Target | Toplevel | Description |
|--------|----------|-------------|
| `default` | *(none)* | HDL fileset only (not a simulation) |
| `sim_fifo_depth8_read_sync` | `tb_fifo_sync` | Reference configuration (`DEPTH = 8`, `SYNC_READ = true`): build and elaboration only (`TESTS_LIST` empty), base of the scenario targets and of the list runs |
| `sim_fifo_depth8_read_sync_<name>` | `tb_fifo_sync` | One target per scenario: `sim_fifo_depth8_read_sync_reset_values`, `_write_read`, `_fill_drain`, `_alternate`, `_half_full`, `_overflow`, `_underflow`, `_push_pop`, `_random`, `_async_reset` (13452 checks in all) |
| `sim_fifo_depth8_read_async` | `tb_fifo_sync` | `DEPTH = 8`, `SYNC_READ = false`, every scenario (13452 checks) |
| `sim_fifo_depth1_read_sync` | `tb_fifo_sync` | `DEPTH = 1`, `SYNC_READ = true`, every scenario but `half_full` (10664 checks) |
| `sim_fifo_depth1_read_async` | `tb_fifo_sync` | `DEPTH = 1`, `SYNC_READ = false`, every scenario but `half_full` (10664 checks) |
| `lint_ghdl` | `asylum.fifo_sync` | GHDL `-Wall -Werror` analysis and elaboration of `fifo_sync`, default generics |
| `lint_ghdl_synth_<config>` | `asylum.fifo_sync` | `ghdl --synth` check (no latch, synthesizable) for 5 generic configurations: `default`, `depth1_read_async`, `depth1_read_sync`, `depth8_read_async`, `depth8_read_sync` |
| `syn_<config>` | `asylum.fifo_sync` | Synthesis with Yosys, Artix-7 and sky130 (see [Resources](#resources)), same 5 configurations as `lint_ghdl_synth_<config>` |

The reference configuration has a build-only base target and one target per scenario: one CI job per scenario, a failure is isolated. Every other configuration has one target that runs its whole list: the `TEST <i>/<N>` header names a failing scenario. FuseSoC replaces the `parameters` list of an inherited target, so each target repeats the generics of its configuration. `DEPTH` and `SYNC_READ` are generics of the testbench too: one build runs every configuration.

Every `sim_*`, `lint_*` and `syn_*` target is a job of the [GitHub CI](https://github.com/deuskane/asylum-component-fifo/actions/workflows/ci.yml), run in the [asylum-env](https://github.com/deuskane/asylum-ci) image (GHDL, FuseSoC, UVVM, Yosys). The `sim`, `lint` and `syn` badges count the passed and failed targets of the last run on `main`.

### How to Run

From a clone of [asylum-project](https://github.com/deuskane/asylum-project) (GHDL and FuseSoC installed, or in the asylum-env image):

```bash
make help                                # variables, rules and targets
make sim_fifo_depth8_read_sync_push_pop  # one scenario, log in log/
make sim_fifo_depth1_read_sync           # every scenario of a configuration
make nonreg_sim                          # every sim_* target
make nonreg_lint                         # every lint_* target
make nonreg_syn                          # every syn_* target (Yosys, figures of Resources)
```

To run a list of scenarios, build the testbench once, then run the list without recompiling with FuseSoC (same `--build-root` and `--no-export` as the Makefile, so that the build of the target is reused; any generic of the target can be overridden after the VLNV):

```bash
make sim_fifo_depth8_read_sync           # build and elaboration (TESTS_LIST empty)
fusesoc --cores-root . run --build-root build --no-export --run --target sim_fifo_depth8_read_sync asylum:component:fifo:1.2.1 --TESTS_LIST=push_pop,random --DEPTH=2
```

To add a scenario: a `tb_fifo_sync_<name>_pkg` package in [sim/fifo_sync/](sim/fifo_sync/) and in the `sim_fifo_sync` fileset, its name in `C_TESTS` and its case in `run_test` of [tb_fifo_sync_tests_pkg](sim/fifo_sync/tb_fifo_sync_tests_pkg.vhd), a `sim_fifo_depth8_read_sync_<name>` target and the name in the `TESTS_LIST` of the other configurations in [FIFO.core](FIFO.core), then `make mk/targets.txt` and `make ci_generate`.

Outside the CI, GHDL writes a waveform `dut.fst`.

## Dependencies and Related IPs

| Core | Repository | Purpose |
|------|------------|---------|
| `asylum:component:ram` | [asylum-component-ram](https://github.com/deuskane/asylum-component-ram) | `ram_1r1w`, the storage |
| `asylum:utils:pkg` | [asylum-utils-pkg](https://github.com/deuskane/asylum-utils-pkg) | Common packages (`math_pkg`: `clog2`); the testbench needs >= 1.10.0 (`string_pkg` lists of `TESTS_LIST`) |
| `asylum:utils:ghdl_synth` | [asylum-utils-generators](https://github.com/deuskane/asylum-utils-generators) | `ghdl --synth` check of the `lint_ghdl_synth_*` targets (a core without dependency: this IP is itself a dependency of `asylum:utils:generators`) |
| `asylum:utils:yosys_synth` | [asylum-utils-generators](https://github.com/deuskane/asylum-utils-generators) | Yosys synthesis of the `syn_*` targets (Artix-7 and sky130) |
| `bitvis:verification:uvvm` | [UVVM](https://github.com/UVVM/UVVM) | Verification library and AXI-Stream BFM |

Used by [asylum-utils-generators](https://github.com/deuskane/asylum-utils-generators) (`csr_fifo`, the FIFO registers of regtool), [asylum-communication-uart](https://github.com/deuskane/asylum-communication-uart) and [asylum-soc-picosoc](https://github.com/deuskane/asylum-soc-picosoc). All the IPs: [asylum-project](https://github.com/deuskane/asylum-project).

## License

Apache License 2.0, see [LICENSE](LICENSE).

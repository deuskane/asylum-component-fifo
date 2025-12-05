# FIFO Component

## Table of Contents

1. [Introduction](#introduction)
2. [HDL Modules](#hdl-modules)
3. [Project Structure](#project-structure)

---

## Introduction

The **FIFO Component** is a synchronous First-In-First-Out (FIFO) buffer implemented in VHDL for the Asylum framework. This component provides a flexible, parameterizable FIFO memory with AXI-Stream interfaces on both the input and output sides.

The FIFO is designed to:
- Buffer data between producer and consumer with configurable width and depth
- Provide real-time status flags (empty, full) on both read and write sides
- Display the number of available elements in the FIFO from both sides
- Use AXI-Stream handshake protocol for seamless data transfer
- Support synchronous clock domains with asynchronous reset


---

## HDL Modules

### fifo_sync

**Entity**: `fifo_sync`

The `fifo_sync` module is a synchronous FIFO that implements a dual-port RAM with read and write pointers to manage the circular buffer.

#### Generics

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `WIDTH` | natural | 8 | Data width in bits |
| `DEPTH` | natural | 4 | FIFO depth (number of elements) |

#### Ports

| Name | Direction | Type | Description |
|------|-----------|------|-------------|
| `clk_i` | in | std_logic | Main clock signal |
| `arst_b_i` | in | std_logic | Asynchronous reset (active low) |
| **Slave AXI-Stream (Write Side)** | | | |
| `s_axis_tvalid_i` | in | std_logic | Data valid flag from producer |
| `s_axis_tready_o` | out | std_logic | Ready flag to producer |
| `s_axis_tdata_i` | in | std_logic_vector(WIDTH-1 downto 0) | Input data from producer |
| `s_axis_nb_elt_empty_o` | out | std_logic_vector(clog2(DEPTH) downto 0) | Number of empty slots in FIFO |
| `s_axis_full_o` | out | std_logic | FIFO full flag |
| `s_axis_empty_o` | out | std_logic | FIFO empty flag |
| **Master AXI-Stream (Read Side)** | | | |
| `m_axis_tvalid_o` | out | std_logic | Data valid flag to consumer |
| `m_axis_tready_i` | in | std_logic | Ready flag from consumer |
| `m_axis_tdata_o` | out | std_logic_vector(WIDTH-1 downto 0) | Output data to consumer |
| `m_axis_nb_elt_full_o` | out | std_logic_vector(clog2(DEPTH) downto 0) | Number of valid elements in FIFO |
| `m_axis_full_o` | out | std_logic | FIFO full flag |
| `m_axis_empty_o` | out | std_logic | FIFO empty flag |

#### Functional Description

The `fifo_sync` module operates as follows:

**Pointer Management**:
- Uses two wraparound counters: a write pointer (`wptr`) and a read pointer (`rptr`)
- Each pointer has one extra bit to distinguish between empty and full conditions
- When the write pointer reaches the read pointer with matching MSBs, the FIFO is empty
- When the write pointer reaches the read pointer with different MSBs, the FIFO is full

**Flag Generation**:
- The **empty** flag is asserted when write and read pointers are equal (same address, same MSB)
- The **full** flag is asserted when write and read pointers point to the same address but have different MSBs
- The **number of elements** are calculated based on the pointer difference

**Data Storage**:
- A synchronous dual-port RAM (1 read, 1 write port) stores the actual data
- Write operations occur on the rising clock edge when `s_axis_tvalid_i` and `s_axis_tready_o` are both high
- Read operations are asynchronous; data is presented at the output when the FIFO is not empty

**AXI-Stream Interface**:
- Follows the AXI-Stream handshake protocol for both input and output
- Input transfer: `s_axis_tvalid_i` AND `s_axis_tready_o`
- Output transfer: `m_axis_tvalid_o` AND `m_axis_tready_i`
- Pointers increment only when transfers occur

**Status Visibility**:
- The write side can monitor how many empty slots are available (`s_axis_nb_elt_empty_o`)
- The read side can monitor how many valid elements are available (`m_axis_nb_elt_full_o`)
- Status flags are updated combinatorially and available immediately

**Assertions**:
- An internal assertion verifies that the sum of available and empty elements always equals the FIFO depth

---

## Project Structure

```
asylum-component-fifo/
├── README.md              # This file
├── FIFO.core              # FuseSoC core file for build integration
├── hdl/
│   ├── fifo_pkg.vhd       # Package containing the fifo_sync component declaration
│   └── fifo_sync.vhd      # FIFO implementation
└── .gitignore
```

### Key Files

- **FIFO.core**: FuseSoC core file that defines the component for integration into larger projects. It specifies dependencies (`asylum:utils:pkg`, `asylum:component:ram`) and build targets (lint with GHDL).
- **fifo_pkg.vhd**: Contains the component declaration for `fifo_sync`, allowing it to be instantiated in other designs.
- **fifo_sync.vhd**: The main FIFO entity and RTL implementation.

### Dependencies

This component depends on:
- `asylum:utils:pkg` - Utility library (including `math_pkg` for `clog2` function)
- `asylum:component:ram` - Synchronous dual-port RAM component

---

## Usage Example

```vhdl
-- Instantiate the FIFO with 16-bit width and 32-element depth
ins_FIFO : fifo_sync
  generic map (
    WIDTH => 16,
    DEPTH => 32
  )
  port map (
    clk_i              => clk,
    arst_b_i           => arst_b,
    s_axis_tvalid_i    => producer_valid,
    s_axis_tready_o    => producer_ready,
    s_axis_tdata_i     => producer_data,
    s_axis_nb_elt_empty_o => fifo_empty_slots,
    s_axis_full_o      => fifo_full,
    s_axis_empty_o     => fifo_empty,
    m_axis_tvalid_o    => consumer_valid,
    m_axis_tready_i    => consumer_ready,
    m_axis_tdata_o     => consumer_data,
    m_axis_nb_elt_full_o => fifo_elements,
    m_axis_full_o      => fifo_full,
    m_axis_empty_o     => fifo_empty
  );
```


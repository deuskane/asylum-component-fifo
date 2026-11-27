-------------------------------------------------------------------------------
-- Title      : tb_fifo_async_clock_stop_pkg
-- Project    : FIFO
-------------------------------------------------------------------------------
-- File       : tb_fifo_async_clock_stop_pkg.vhd
-- Author     : mrosiere
-------------------------------------------------------------------------------
-- Description: Scenario clock_stop : a side sees the transfer of the other
--              side even when the clock of the other side stops right
--              after it (as TCK) : a word written, then the write clock
--              stopped, is read ; a word read in a full FIFO, then the read
--              clock stopped, frees a place on the write side
-------------------------------------------------------------------------------
-- Copyright (c) 2026
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author   Description
-- 2026-11-26  1.0      mrosiere Created
-------------------------------------------------------------------------------

library ieee;
use     ieee.std_logic_1164.all;
use     ieee.numeric_std.all;

library uvvm_util;
context uvvm_util.uvvm_util_context;

library bitvis_vip_axistream;
use     bitvis_vip_axistream.axistream_bfm_pkg.all;

library work;
use     work.tb_fifo_sync_bfm_pkg.all;
use     work.tb_fifo_async_bfm_pkg.all;

package tb_fifo_async_clock_stop_pkg is

  procedure run
    (constant cfg      : in    tb_cfg_t         -- DEPTH and clock periods
    ;signal   s_clk    : in    std_logic        -- Clock of the write side
    ;signal   m_clk    : in    std_logic        -- Clock of the read side
    ;signal   arst_b   : out   std_logic
    ;signal   axis_s   : inout t_axistream_if   -- Write side (s_axis)
    ;signal   axis_m   : inout t_axistream_if   -- Read side (m_axis)
    ;signal   status   : in    status_t         -- Flags and fill levels
    ;signal   xfer     : in    tb_xfer_t        -- Time of the last transfer of each side
    ;signal   ena      : out   tb_ena_t         -- Clock enables
    );

end package tb_fifo_async_clock_stop_pkg;

package body tb_fifo_async_clock_stop_pkg is

  procedure run
    (constant cfg      : in    tb_cfg_t         -- DEPTH and clock periods
    ;signal   s_clk    : in    std_logic        -- Clock of the write side
    ;signal   m_clk    : in    std_logic        -- Clock of the read side
    ;signal   arst_b   : out   std_logic
    ;signal   axis_s   : inout t_axistream_if   -- Write side (s_axis)
    ;signal   axis_m   : inout t_axistream_if   -- Read side (m_axis)
    ;signal   status   : in    status_t         -- Flags and fill levels
    ;signal   xfer     : in    tb_xfer_t        -- Time of the last transfer of each side
    ;signal   ena      : out   tb_ena_t         -- Clock enables
    ) is
  begin
    -- Write, then the write clock stops : the word reaches the read side
    push(word(16#90#), "Write, then s_clk stopped", s_clk, axis_s);
    ena.s <= false;
    for i in 1 to 6
    loop
      wait until falling_edge(m_clk);
    end loop;
    check_value(axis_m.tvalid, '1', error, "m_axis_tvalid_o, write clock stopped after the write", C_TB_SCOPE);
    pop(word(16#90#), "Read, write clock stopped", m_clk, axis_m);
    ena.s <= true;

    -- Full FIFO, one read, then the read clock stops : the place reaches
    -- the write side
    for k in 1 to cfg.depth
    loop
      push(word(16#A0#+k), "Fill " & to_string(k), s_clk, axis_s);
    end loop;
    settle(cfg);
    check_value(axis_s.tready, '0', error, "s_axis_tready_o, full", C_TB_SCOPE);
    pop(word(16#A1#), "Read, then m_clk stopped", m_clk, axis_m);
    ena.m <= false;
    for i in 1 to 6
    loop
      wait until falling_edge(s_clk);
    end loop;
    check_value(axis_s.tready, '1', error, "s_axis_tready_o, read clock stopped after the read", C_TB_SCOPE);
    ena.m <= true;
    for k in 2 to cfg.depth
    loop
      pop(word(16#A0#+k), "Drain " & to_string(k), m_clk, axis_m);
    end loop;
  end procedure;

end package body tb_fifo_async_clock_stop_pkg;

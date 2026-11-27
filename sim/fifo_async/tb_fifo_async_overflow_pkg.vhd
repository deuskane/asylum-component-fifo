-------------------------------------------------------------------------------
-- Title      : tb_fifo_async_overflow_pkg
-- Project    : FIFO
-------------------------------------------------------------------------------
-- File       : tb_fifo_async_overflow_pkg.vhd
-- Author     : mrosiere
-------------------------------------------------------------------------------
-- Description: Scenario overflow : write refused when full (s_axis_tready_o = 0
--              on every cycle, word not stored), a read frees a place seen on
--              the write side after the synchronizer (latency checked), the
--              words read in order
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

package tb_fifo_async_overflow_pkg is

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

end package tb_fifo_async_overflow_pkg;

package body tb_fifo_async_overflow_pkg is

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
    for k in 1 to cfg.depth
    loop
      push(word(16#50#+k), "Fill " & to_string(k), s_clk, axis_s);
    end loop;
    settle(cfg);
    chk_level(cfg.depth, cfg.depth, "Full", axis_s, axis_m, status);

    -- Write refused while full
    for i in 1 to 8
    loop
      wait until falling_edge(s_clk);
      axis_s.tvalid <= '1';
      axis_s.tdata  <= word(16#EE#);
      check_value(axis_s.tready, '0', error, "s_axis_tready_o, full", C_TB_SCOPE);
    end loop;
    wait until falling_edge(s_clk);
    axis_s.tvalid <= '0';

    -- One read : a free place on the write side after the synchronizer
    pop(word(16#51#), "Read 1", m_clk, axis_m);
    if axis_s.tready /= '1'
    then
      wait until axis_s.tready = '1' for 4*(cfg.s_period + cfg.m_period);
    end if;
    wait for 0 ns;
    check_value(axis_s.tready, '1', error, "s_axis_tready_o after a read", C_TB_SCOPE);
    check_latency(xfer.m_time, xfer.tready_rise, cfg.s_period, "Read to s_axis_tready_o");

    push(word(16#5F#), "Write after the read", s_clk, axis_s);
    for k in 2 to cfg.depth
    loop
      pop(word(16#50#+k), "Read " & to_string(k), m_clk, axis_m);
    end loop;
    pop(word(16#5F#), "Read of the word written after the read", m_clk, axis_m);
    settle(cfg);
    chk_level(0, cfg.depth, "Empty, refused word not stored", axis_s, axis_m, status);
  end procedure;

end package body tb_fifo_async_overflow_pkg;

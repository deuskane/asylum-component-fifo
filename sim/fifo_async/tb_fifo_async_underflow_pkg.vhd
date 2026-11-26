-------------------------------------------------------------------------------
-- Title      : tb_fifo_async_underflow_pkg
-- Project    : FIFO
-------------------------------------------------------------------------------
-- File       : tb_fifo_async_underflow_pkg.vhd
-- Author     : mrosiere
-------------------------------------------------------------------------------
-- Description: Scenario underflow : read side never valid while empty
--              (m_axis_tready_i = 1), a written word seen on the read side
--              after the synchronizer (latency checked), then read
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

package tb_fifo_async_underflow_pkg is

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

end package tb_fifo_async_underflow_pkg;

package body tb_fifo_async_underflow_pkg is

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
    for i in 1 to 8
    loop
      wait until falling_edge(m_clk);
      axis_m.tready <= '1';
      check_value(axis_m.tvalid, '0', error, "m_axis_tvalid_o, empty", C_TB_SCOPE);
    end loop;
    wait until falling_edge(m_clk);
    axis_m.tready <= '0';

    for k in 1 to minimum(2, cfg.depth)
    loop
      push(word(16#60#+k), "Write " & to_string(k), s_clk, axis_s);
      if axis_m.tvalid /= '1'
      then
        wait until axis_m.tvalid = '1' for 4*(cfg.s_period + cfg.m_period);
      end if;
      wait for 0 ns;
      check_value(axis_m.tvalid, '1', error, "m_axis_tvalid_o after a write", C_TB_SCOPE);
      check_latency(xfer.s_time, xfer.tvalid_rise, cfg.m_period, "Write to m_axis_tvalid_o");
      pop(word(16#60#+k), "Read " & to_string(k), m_clk, axis_m);
      wait until falling_edge(m_clk);
      check_value(axis_m.tvalid, '0', error, "m_axis_tvalid_o, empty again", C_TB_SCOPE);
    end loop;
  end procedure;

end package body tb_fifo_async_underflow_pkg;

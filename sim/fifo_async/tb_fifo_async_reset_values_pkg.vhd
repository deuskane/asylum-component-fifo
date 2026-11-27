-------------------------------------------------------------------------------
-- Title      : tb_fifo_async_reset_values_pkg
-- Project    : FIFO
-------------------------------------------------------------------------------
-- File       : tb_fifo_async_reset_values_pkg.vhd
-- Author     : mrosiere
-------------------------------------------------------------------------------
-- Description: Scenario reset_values : flags and fill levels of both sides after
--              reset, read side never valid while nothing is written
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

package tb_fifo_async_reset_values_pkg is

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

end package tb_fifo_async_reset_values_pkg;

package body tb_fifo_async_reset_values_pkg is

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
    chk_level(0, cfg.depth, "After reset", axis_s, axis_m, status);
    for i in 1 to 8
    loop
      wait until falling_edge(m_clk);
      axis_m.tready <= '1';
      check_value(axis_m.tvalid, '0', error, "m_axis_tvalid_o, nothing written", C_TB_SCOPE);
    end loop;
    axis_m.tready <= '0';
    settle(cfg);
    chk_level(0, cfg.depth, "Idle", axis_s, axis_m, status);
  end procedure;

end package body tb_fifo_async_reset_values_pkg;

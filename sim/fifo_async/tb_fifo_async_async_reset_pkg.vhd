-------------------------------------------------------------------------------
-- Title      : tb_fifo_async_async_reset_pkg
-- Project    : FIFO
-------------------------------------------------------------------------------
-- File       : tb_fifo_async_async_reset_pkg.vhd
-- Author     : mrosiere
-------------------------------------------------------------------------------
-- Description: Scenario async_reset : words stored, then a reset pulse empties
--              both sides (no word read after it), words written after the
--              reset read back
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

package tb_fifo_async_async_reset_pkg is

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

end package tb_fifo_async_async_reset_pkg;

package body tb_fifo_async_async_reset_pkg is

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
    for k in 1 to minimum(3, cfg.depth)
    loop
      push(word(16#70#+k), "Before reset " & to_string(k), s_clk, axis_s);
    end loop;
    settle(cfg);
    chk_level(minimum(3, cfg.depth), cfg.depth, "Before reset", axis_s, axis_m, status);
    do_reset(cfg, s_clk, arst_b);
    chk_level(0, cfg.depth, "Just after reset", axis_s, axis_m, status);
    settle(cfg);
    chk_level(0, cfg.depth, "After reset", axis_s, axis_m, status);
    for k in 1 to minimum(2, cfg.depth)
    loop
      push(word(16#78#+k), "After reset " & to_string(k), s_clk, axis_s);
      pop (word(16#78#+k), "After reset " & to_string(k), m_clk, axis_m);
    end loop;
  end procedure;

end package body tb_fifo_async_async_reset_pkg;

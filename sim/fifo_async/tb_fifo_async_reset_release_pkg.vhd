-------------------------------------------------------------------------------
-- Title      : tb_fifo_async_reset_release_pkg
-- Project    : FIFO
-------------------------------------------------------------------------------
-- File       : tb_fifo_async_reset_release_pkg.vhd
-- Author     : mrosiere
-------------------------------------------------------------------------------
-- Description: Scenario reset_release : during a reset s_axis_tready_o and
--              m_axis_tvalid_o are 0 (a word offered is not written) ; the
--              reset is released on a falling edge of s_clk, the write side
--              leaves it on the second rising edge of s_clk (latency
--              checked), the read side on m_clk ; words go through after it
-------------------------------------------------------------------------------
-- Copyright (c) 2026
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author   Description
-- 2026-11-27  1.0      mrosiere Created
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

package tb_fifo_async_reset_release_pkg is

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

end package tb_fifo_async_reset_release_pkg;

package body tb_fifo_async_reset_release_pkg is

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
    variable v_t0 : time;
  begin
    -- Reset with a word offered : not written
    axis_s.tvalid <= '1';
    axis_s.tdata  <= word(16#B0#);
    arst_b        <= '0';
    wait for cfg.s_period/4;
    for i in 1 to 4
    loop
      wait until falling_edge(s_clk);
      check_value(axis_s.tready, '0', error, "s_axis_tready_o during the reset", C_TB_SCOPE);
      check_value(axis_m.tvalid, '0', error, "m_axis_tvalid_o during the reset", C_TB_SCOPE);
    end loop;
    axis_s.tvalid <= '0';

    -- Release on a falling edge of s_clk
    wait until falling_edge(s_clk);
    arst_b <= '1';
    v_t0   := now;
    wait until axis_s.tready = '1' for 4*cfg.s_period;
    wait for 0 ns;
    check_value(axis_s.tready, '1', error, "s_axis_tready_o after the release", C_TB_SCOPE);
    check_latency(v_t0, xfer.tready_rise, cfg.s_period, "Release to s_axis_tready_o");
    settle(cfg);
    chk_level(0, cfg.depth, "After the release, the word offered during the reset not stored", axis_s, axis_m, status);

    for k in 1 to minimum(3, cfg.depth)
    loop
      push(word(16#B0#+k), "After the release " & to_string(k), s_clk, axis_s);
    end loop;
    for k in 1 to minimum(3, cfg.depth)
    loop
      pop (word(16#B0#+k), "After the release " & to_string(k), m_clk, axis_m);
    end loop;
  end procedure;

end package body tb_fifo_async_reset_release_pkg;

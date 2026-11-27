-------------------------------------------------------------------------------
-- Title      : tb_fifo_async_reset_traffic_pkg
-- Project    : FIFO
-------------------------------------------------------------------------------
-- File       : tb_fifo_async_reset_traffic_pkg.vhd
-- Author     : mrosiere
-------------------------------------------------------------------------------
-- Description: Scenario reset_traffic : writer and reader active at the same
--              time (random valid / ready, the words read checked in order),
--              a reset asserted and released in the middle of the traffic at
--              times aligned with neither clock : both sides empty after it,
--              the words of the traffic lost, new words read in order
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

package tb_fifo_async_reset_traffic_pkg is

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

end package tb_fifo_async_reset_traffic_pkg;

package body tb_fifo_async_reset_traffic_pkg is

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
    variable v_wr      : natural := 0;
    variable v_rd      : natural := 0;
    variable v_s_hs    : boolean := false;
    variable v_m_hs    : boolean := false;
    variable v_valid   : boolean;
    variable v_ready   : boolean;
    variable v_seed1   : positive := 13;
    variable v_seed2   : positive := 17;
    variable v_r       : real;
  begin
    -- Traffic during 8 x DEPTH + 20 falling edges of the two clocks
    for e in 1 to 8*cfg.depth + 20
    loop
      wait until falling_edge(s_clk) or falling_edge(m_clk);
      if falling_edge(s_clk)
      then
        if v_s_hs
        then
          v_wr := v_wr + 1;
        end if;
        ieee.math_real.uniform(v_seed1, v_seed2, v_r);
        v_valid       := v_r < 0.7;
        axis_s.tvalid <= to_sl(v_valid);
        axis_s.tdata  <= word(16#40# + v_wr);
        v_s_hs        := v_valid and axis_s.tready = '1';
      end if;
      if falling_edge(m_clk)
      then
        if v_m_hs
        then
          v_rd := v_rd + 1;
        end if;
        if axis_m.tvalid = '1'
        then
          check_value(axis_m.tdata, word(16#40# + v_rd), error, "Traffic before the reset : word " & to_string(v_rd), C_TB_SCOPE);
        end if;
        ieee.math_real.uniform(v_seed1, v_seed2, v_r);
        v_ready       := v_r < 0.5;
        axis_m.tready <= to_sl(v_ready);
        v_m_hs        := v_ready and axis_m.tvalid = '1';
      end if;
    end loop;
    check_value(v_wr > 0 and v_rd > 0, true, error, "Words written and read before the reset", C_TB_SCOPE);

    -- Reset in the middle of the traffic, at times aligned with no clock
    wait for cfg.s_period/3;
    arst_b        <= '0';
    axis_s.tvalid <= '0';
    axis_m.tready <= '0';
    wait for 2*(cfg.s_period + cfg.m_period) + cfg.m_period/7;
    arst_b        <= '1';
    settle(cfg);
    chk_level(0, cfg.depth, "After the reset in the traffic", axis_s, axis_m, status);

    for k in 1 to minimum(3, cfg.depth)
    loop
      push(word(16#C0#+k), "After the reset " & to_string(k), s_clk, axis_s);
    end loop;
    for k in 1 to minimum(3, cfg.depth)
    loop
      pop (word(16#C0#+k), "After the reset " & to_string(k), m_clk, axis_m);
    end loop;
  end procedure;

end package body tb_fifo_async_reset_traffic_pkg;

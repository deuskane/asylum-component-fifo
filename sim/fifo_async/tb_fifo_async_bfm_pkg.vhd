-------------------------------------------------------------------------------
-- Title      : tb_fifo_async_bfm_pkg
-- Project    : FIFO
-------------------------------------------------------------------------------
-- File       : tb_fifo_async_bfm_pkg.vhd
-- Author     : mrosiere
-------------------------------------------------------------------------------
-- Description: Helpers of the tb_fifo_async scenarios, on top of
--              tb_fifo_sync_bfm_pkg (status_t, word, push, pop, chk_level) :
--              configuration (DEPTH, clock periods), times of the last
--              transfers, wait for the synchronizers (settle), reset,
--              check of the latency of a synchronized pointer
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

package tb_fifo_async_bfm_pkg is

  -- Configuration of the testbench
  type tb_cfg_t is record
    depth          : positive;
    s_period       : time;               -- Period of s_clk (write side)
    m_period       : time;               -- Period of m_clk (read side)
  end record tb_cfg_t;

  -- Times of the last transfer of each side (rising edge of its clock) and
  -- of the last rise of s_axis_tready_o and m_axis_tvalid_o (monitor of
  -- tb_fifo_async)
  type tb_xfer_t is record
    s_time         : time;
    m_time         : time;
    tready_rise    : time;
    tvalid_rise    : time;
  end record tb_xfer_t;

  -- Enables of the clocks (a scenario may stop one clock)
  type tb_ena_t is record
    s              : boolean;            -- s_clk running
    m              : boolean;            -- m_clk running
  end record tb_ena_t;

  -- '1' for true
  function to_sl
    (constant b        : in    boolean
    ) return std_logic;

  -- Long enough for a pointer to cross to the other side (both directions)
  procedure settle
    (constant cfg      : in    tb_cfg_t
    );

  -- Reset pulse (both sides idle), released on a falling edge of s_clk,
  -- then 3 cycles of each clock (reset released on each side)
  procedure do_reset
    (constant cfg      : in    tb_cfg_t
    ;signal   s_clk    : in    std_logic
    ;signal   arst_b   : out   std_logic
    );

  -- Latency between a transfer at time t0 on the source side and its effect
  -- at time t1 on the destination side (clock period t_dst) : the Gray
  -- register of the source changes with the transfer, then two flip-flops
  -- of the destination clock : t_dst < t1 - t0 <= 2 t_dst
  procedure check_latency
    (constant t0       : in    time
    ;constant t1       : in    time
    ;constant t_dst    : in    time
    ;constant msg      : in    string
    );

end package tb_fifo_async_bfm_pkg;

package body tb_fifo_async_bfm_pkg is

  function to_sl
    (constant b        : in    boolean
    ) return std_logic is
  begin
    if b
    then
      return '1';
    else
      return '0';
    end if;
  end function;

  procedure settle
    (constant cfg      : in    tb_cfg_t
    ) is
  begin
    wait for 4*(cfg.s_period + cfg.m_period);
  end procedure;

  procedure do_reset
    (constant cfg      : in    tb_cfg_t
    ;signal   s_clk    : in    std_logic
    ;signal   arst_b   : out   std_logic
    ) is
  begin
    arst_b <= '0';
    wait for 4*(cfg.s_period + cfg.m_period);
    wait until falling_edge(s_clk);
    arst_b <= '1';
    wait for 3*(cfg.s_period + cfg.m_period);
  end procedure;

  procedure check_latency
    (constant t0       : in    time
    ;constant t1       : in    time
    ;constant t_dst    : in    time
    ;constant msg      : in    string
    ) is
    constant L : time := t1 - t0;
  begin
    check_value(L > t_dst and L <= 2*t_dst, true, error,
                msg & " : latency " & to_string(L) & " in ]" & to_string(t_dst) & ", " & to_string(2*t_dst) & "]", C_TB_SCOPE);
  end procedure;

end package body tb_fifo_async_bfm_pkg;

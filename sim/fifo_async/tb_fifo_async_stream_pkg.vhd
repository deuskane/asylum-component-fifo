-------------------------------------------------------------------------------
-- Title      : tb_fifo_async_stream_pkg
-- Project    : FIFO
-------------------------------------------------------------------------------
-- File       : tb_fifo_async_stream_pkg.vhd
-- Author     : mrosiere
-------------------------------------------------------------------------------
-- Description: Scenario stream : writer and reader active at the same time on
--              their own clocks, random valid / ready, 4 x DEPTH + 3 words in
--              each of 2 profiles (writer faster : the FIFO fills, reader
--              faster : it empties), every word read in order
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

package tb_fifo_async_stream_pkg is

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

end package tb_fifo_async_stream_pkg;

package body tb_fifo_async_stream_pkg is

  -- Writer (probability of tvalid pw %) and reader (probability of tready
  -- pr %) on their falling edges ; n words
  procedure stream
    (constant n        : in    natural
    ;constant pw       : in    natural
    ;constant pr       : in    natural
    ;constant first    : in    natural
    ;constant msg      : in    string
    ;signal   s_clk    : in    std_logic
    ;signal   m_clk    : in    std_logic
    ;signal   axis_s   : inout t_axistream_if
    ;signal   axis_m   : inout t_axistream_if
    ) is
    variable v_wr      : natural := 0;   -- Words written
    variable v_rd      : natural := 0;   -- Words read
    variable v_s_hs    : boolean := false; -- tvalid and tready of the write side, stable until the next rising edge
    variable v_m_hs    : boolean := false; -- tvalid and tready of the read side, stable until the next rising edge
    variable v_valid   : boolean;
    variable v_ready   : boolean;
    variable v_seed1   : positive := 7;
    variable v_seed2   : positive := 11;
    variable v_r       : real;
    variable v_edges   : natural := 0;   -- Falling edges seen (timeout)
  begin
    while v_rd < n
    loop
      wait until falling_edge(s_clk) or falling_edge(m_clk);
      v_edges := v_edges + 1;
      if v_edges > 100*n
      then
        alert(TB_ERROR, msg & " : timeout, " & to_string(v_wr) & " words written, " & to_string(v_rd) & " read", C_TB_SCOPE);
        exit;
      end if;
      if falling_edge(s_clk)
      then
        -- Transfer of the last rising edge
        if v_s_hs
        then
          v_wr := v_wr + 1;
        end if;
        ieee.math_real.uniform(v_seed1, v_seed2, v_r);
        v_valid       := v_wr < n and v_r*100.0 < real(pw);
        axis_s.tvalid <= to_sl(v_valid);
        axis_s.tdata  <= word(first + v_wr);
        v_s_hs        := v_valid and axis_s.tready = '1';
      end if;
      if falling_edge(m_clk)
      then
        if v_m_hs
        then
          v_rd := v_rd + 1;
        end if;
        -- Head word checked when presented
        if axis_m.tvalid = '1' and v_rd < n
        then
          check_value(axis_m.tdata, word(first + v_rd), error, msg & " : word " & to_string(v_rd), C_TB_SCOPE);
        end if;
        ieee.math_real.uniform(v_seed1, v_seed2, v_r);
        v_ready       := v_r*100.0 < real(pr);
        axis_m.tready <= to_sl(v_ready);
        v_m_hs        := v_ready and axis_m.tvalid = '1';
      end if;
    end loop;
    axis_s.tvalid <= '0';
    axis_m.tready <= '0';
    check_value(v_wr, n, error, msg & " : words written", C_TB_SCOPE);
  end procedure;

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
    constant N : natural := 4*cfg.depth + 3;
  begin
    stream(N, 90, 30, 16#00#, "Writer faster", s_clk, m_clk, axis_s, axis_m);
    settle(cfg);
    chk_level(0, cfg.depth, "Writer faster, empty at the end", axis_s, axis_m, status);
    stream(N, 30, 90, 16#80#, "Reader faster", s_clk, m_clk, axis_s, axis_m);
    settle(cfg);
    chk_level(0, cfg.depth, "Reader faster, empty at the end", axis_s, axis_m, status);
  end procedure;

end package body tb_fifo_async_stream_pkg;

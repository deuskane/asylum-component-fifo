-------------------------------------------------------------------------------
-- Title      : tb_fifo_async_tests_pkg
-- Project    : FIFO
-------------------------------------------------------------------------------
-- File       : tb_fifo_async_tests_pkg.vhd
-- Author     : mrosiere
-------------------------------------------------------------------------------
-- Description: Scenarios of tb_fifo_async : names (valid items of
--              TESTS_LIST) and dispatch (run_test) to the package of each
--              scenario (tb_fifo_async_<name>_pkg)
-------------------------------------------------------------------------------
-- Copyright (c) 2026
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author   Description
-- 2026-11-26  1.0      mrosiere Created
-------------------------------------------------------------------------------

library ieee;
use     ieee.std_logic_1164.all;

library uvvm_util;
context uvvm_util.uvvm_util_context;

library bitvis_vip_axistream;
use     bitvis_vip_axistream.axistream_bfm_pkg.all;

library asylum;
use     asylum.string_pkg.all;

library work;
use     work.tb_fifo_sync_bfm_pkg.all;
use     work.tb_fifo_async_bfm_pkg.all;

package tb_fifo_async_tests_pkg is

  -- Names of the scenarios (valid items of TESTS_LIST)
  constant C_TESTS : string := "reset_values,write_read,fill_drain,overflow,underflow,stream,async_reset,clock_stop";

  -- Run the scenario name
  procedure run_test
    (constant name     : in    string
    ;constant cfg      : in    tb_cfg_t
    ;signal   s_clk    : in    std_logic
    ;signal   m_clk    : in    std_logic
    ;signal   arst_b   : out   std_logic
    ;signal   axis_s   : inout t_axistream_if
    ;signal   axis_m   : inout t_axistream_if
    ;signal   status   : in    status_t
    ;signal   xfer     : in    tb_xfer_t
    ;signal   ena      : out   tb_ena_t
    );

end package tb_fifo_async_tests_pkg;

package body tb_fifo_async_tests_pkg is

  procedure run_test
    (constant name     : in    string
    ;constant cfg      : in    tb_cfg_t
    ;signal   s_clk    : in    std_logic
    ;signal   m_clk    : in    std_logic
    ;signal   arst_b   : out   std_logic
    ;signal   axis_s   : inout t_axistream_if
    ;signal   axis_m   : inout t_axistream_if
    ;signal   status   : in    status_t
    ;signal   xfer     : in    tb_xfer_t
    ;signal   ena      : out   tb_ena_t
    ) is
  begin
    if    string_eq(name, "reset_values")
    then
      work.tb_fifo_async_reset_values_pkg.run(cfg, s_clk, m_clk, arst_b, axis_s, axis_m, status, xfer, ena);
    elsif string_eq(name, "write_read")
    then
      work.tb_fifo_async_write_read_pkg.run(cfg, s_clk, m_clk, arst_b, axis_s, axis_m, status, xfer, ena);
    elsif string_eq(name, "fill_drain")
    then
      work.tb_fifo_async_fill_drain_pkg.run(cfg, s_clk, m_clk, arst_b, axis_s, axis_m, status, xfer, ena);
    elsif string_eq(name, "overflow")
    then
      work.tb_fifo_async_overflow_pkg.run(cfg, s_clk, m_clk, arst_b, axis_s, axis_m, status, xfer, ena);
    elsif string_eq(name, "underflow")
    then
      work.tb_fifo_async_underflow_pkg.run(cfg, s_clk, m_clk, arst_b, axis_s, axis_m, status, xfer, ena);
    elsif string_eq(name, "stream")
    then
      work.tb_fifo_async_stream_pkg.run(cfg, s_clk, m_clk, arst_b, axis_s, axis_m, status, xfer, ena);
    elsif string_eq(name, "async_reset")
    then
      work.tb_fifo_async_async_reset_pkg.run(cfg, s_clk, m_clk, arst_b, axis_s, axis_m, status, xfer, ena);
    elsif string_eq(name, "clock_stop")
    then
      work.tb_fifo_async_clock_stop_pkg.run(cfg, s_clk, m_clk, arst_b, axis_s, axis_m, status, xfer, ena);
    else
      alert(TB_ERROR, "Unknown test " & name, C_TB_SCOPE);
    end if;
  end procedure;

end package body tb_fifo_async_tests_pkg;

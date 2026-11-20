-------------------------------------------------------------------------------
-- Title      : tb_fifo_sync_tests_pkg
-- Project    : Asylum
-------------------------------------------------------------------------------
-- File       : tb_fifo_sync_tests_pkg.vhd
-- Author     : Mathieu Rosiere
-------------------------------------------------------------------------------
-- Description: Scenarios of tb_fifo_sync : names (valid items of TESTS_LIST)
--              and dispatch (run_test) to the package of each scenario
--              (tb_fifo_sync_<name>_pkg)
-------------------------------------------------------------------------------
-- Copyright (c) 2026
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author   Description
-- 2026-11-20  1.0      mrosiere Created
-------------------------------------------------------------------------------

library ieee;
use     ieee.std_logic_1164.all;
use     ieee.numeric_std.all;

library uvvm_util;
context uvvm_util.uvvm_util_context;

library bitvis_vip_axistream;
use     bitvis_vip_axistream.axistream_bfm_pkg.all;

library asylum;
use     asylum.string_pkg.all;

library work;
use     work.tb_fifo_sync_bfm_pkg.all;

package tb_fifo_sync_tests_pkg is

  -- Names of the scenarios (valid items of TESTS_LIST)
  constant C_TESTS : string := "reset_values,write_read,fill_drain,alternate,half_full,overflow,underflow,push_pop,random,async_reset";

  -- Run the scenario name
  procedure run_test
    (constant name     : in    string
    ;constant depth    : in    positive         -- DEPTH of the DUT
    ;signal   clk      : in    std_logic
    ;signal   arst_b   : out   std_logic
    ;signal   axis_s   : inout t_axistream_if   -- Write side (s_axis)
    ;signal   axis_m   : inout t_axistream_if   -- Read side (m_axis)
    ;signal   status   : in    status_t         -- Flags and fill levels
    );

end package tb_fifo_sync_tests_pkg;

package body tb_fifo_sync_tests_pkg is

  procedure run_test
    (constant name     : in    string
    ;constant depth    : in    positive         -- DEPTH of the DUT
    ;signal   clk      : in    std_logic
    ;signal   arst_b   : out   std_logic
    ;signal   axis_s   : inout t_axistream_if   -- Write side (s_axis)
    ;signal   axis_m   : inout t_axistream_if   -- Read side (m_axis)
    ;signal   status   : in    status_t         -- Flags and fill levels
    ) is
  begin
    if    string_eq(name, "reset_values")
    then
      work.tb_fifo_sync_reset_values_pkg.run(depth, clk, axis_s, axis_m, status);
    elsif string_eq(name, "write_read")
    then
      work.tb_fifo_sync_write_read_pkg.run(depth, clk, axis_s, axis_m, status);
    elsif string_eq(name, "fill_drain")
    then
      work.tb_fifo_sync_fill_drain_pkg.run(depth, clk, axis_s, axis_m, status);
    elsif string_eq(name, "alternate")
    then
      work.tb_fifo_sync_alternate_pkg.run(depth, clk, axis_s, axis_m, status);
    elsif string_eq(name, "half_full")
    then
      work.tb_fifo_sync_half_full_pkg.run(depth, clk, axis_s, axis_m, status);
    elsif string_eq(name, "overflow")
    then
      work.tb_fifo_sync_overflow_pkg.run(depth, clk, axis_s, axis_m, status);
    elsif string_eq(name, "underflow")
    then
      work.tb_fifo_sync_underflow_pkg.run(depth, clk, axis_s, axis_m, status);
    elsif string_eq(name, "push_pop")
    then
      work.tb_fifo_sync_push_pop_pkg.run(depth, clk, arst_b, axis_s, axis_m, status);
    elsif string_eq(name, "random")
    then
      work.tb_fifo_sync_random_pkg.run(depth, clk, axis_s, axis_m, status);
    elsif string_eq(name, "async_reset")
    then
      work.tb_fifo_sync_async_reset_pkg.run(depth, clk, arst_b, axis_s, axis_m, status);
    else
      alert(TB_ERROR, "Unknown test " & name, C_TB_SCOPE);
    end if;
  end procedure;

end package body tb_fifo_sync_tests_pkg;

-------------------------------------------------------------------------------
-- Title      : tb_fifo_sync_reset_values_pkg
-- Project    : Asylum
-------------------------------------------------------------------------------
-- File       : tb_fifo_sync_reset_values_pkg.vhd
-- Author     : Mathieu Rosiere
-------------------------------------------------------------------------------
-- Description: Scenario reset_values of tb_fifo_sync, from reset :
--              Flags and fill levels after reset (empty), then idle cycles : nothing
--              is written while s_axis_tvalid_i = 0
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

library work;
use     work.tb_fifo_sync_bfm_pkg.all;

package tb_fifo_sync_reset_values_pkg is

  -- Flags and fill levels after reset (empty), then idle cycles : nothing
  -- is written while s_axis_tvalid_i = 0
  procedure run
    (constant depth    : in    positive         -- DEPTH of the DUT
    ;signal   clk      : in    std_logic
    ;signal   axis_s   : inout t_axistream_if   -- Write side (s_axis)
    ;signal   axis_m   : inout t_axistream_if   -- Read side (m_axis)
    ;signal   status   : in    status_t         -- Flags and fill levels
    );

end package tb_fifo_sync_reset_values_pkg;

package body tb_fifo_sync_reset_values_pkg is

  procedure run
    (constant depth    : in    positive         -- DEPTH of the DUT
    ;signal   clk      : in    std_logic
    ;signal   axis_s   : inout t_axistream_if   -- Write side (s_axis)
    ;signal   axis_m   : inout t_axistream_if   -- Read side (m_axis)
    ;signal   status   : in    status_t         -- Flags and fill levels
    ) is
    variable model : model_t := model_empty(0);
  begin
    for i in 1 to 4 loop
      cycle(model, false, false, "idle " & to_string(i), depth, clk, axis_s, axis_m, status);
    end loop;
    idle(clk, axis_s, axis_m);
  end procedure;

end package body tb_fifo_sync_reset_values_pkg;

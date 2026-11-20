-------------------------------------------------------------------------------
-- Title      : tb_fifo_sync_overflow_pkg
-- Project    : Asylum
-------------------------------------------------------------------------------
-- File       : tb_fifo_sync_overflow_pkg.vhd
-- Author     : Mathieu Rosiere
-------------------------------------------------------------------------------
-- Description: Scenario overflow of tb_fifo_sync, from reset :
--              FIFO filled, then 4 more writes refused (s_axis_tready_o = 0, head
--              word unchanged), then drain : the DEPTH words are read
--              unchanged ; flags, fill levels and data checked on every
--              cycle
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

package tb_fifo_sync_overflow_pkg is

  -- FIFO filled, then 4 more writes refused (s_axis_tready_o = 0, head
  -- word unchanged), then drain : the DEPTH words are read
  -- unchanged ; flags, fill levels and data checked on every
  -- cycle
  procedure run
    (constant depth    : in    positive         -- DEPTH of the DUT
    ;signal   clk      : in    std_logic
    ;signal   axis_s   : inout t_axistream_if   -- Write side (s_axis)
    ;signal   axis_m   : inout t_axistream_if   -- Read side (m_axis)
    ;signal   status   : in    status_t         -- Flags and fill levels
    );

end package tb_fifo_sync_overflow_pkg;

package body tb_fifo_sync_overflow_pkg is

  procedure run
    (constant depth    : in    positive         -- DEPTH of the DUT
    ;signal   clk      : in    std_logic
    ;signal   axis_s   : inout t_axistream_if   -- Write side (s_axis)
    ;signal   axis_m   : inout t_axistream_if   -- Read side (m_axis)
    ;signal   status   : in    status_t         -- Flags and fill levels
    ) is
    variable model : model_t := model_empty(16#60#);
  begin
    for i in 1 to depth loop
      cycle(model, true , false, "fill"           , depth, clk, axis_s, axis_m, status);
    end loop;
    for i in 1 to 4 loop
      cycle(model, true , false, "write when full", depth, clk, axis_s, axis_m, status);
    end loop;
    while model.wr /= model.rd loop
      cycle(model, false, true , "drain"          , depth, clk, axis_s, axis_m, status);
    end loop;
    cycle  (model, false, false, "empty"          , depth, clk, axis_s, axis_m, status);
    idle(clk, axis_s, axis_m);
  end procedure;

end package body tb_fifo_sync_overflow_pkg;

-------------------------------------------------------------------------------
-- Title      : tb_fifo_sync_async_reset_pkg
-- Project    : Asylum
-------------------------------------------------------------------------------
-- File       : tb_fifo_sync_async_reset_pkg.vhd
-- Author     : Mathieu Rosiere
-------------------------------------------------------------------------------
-- Description: Scenario async_reset of tb_fifo_sync, from reset :
--              FIFO full, reset asserted between two clock edges : the flags and
--              fill levels are those of an empty FIFO without clock edge ;
--              after the release, the words written are read back (no stale
--              word)
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

package tb_fifo_sync_async_reset_pkg is

  -- FIFO full, reset asserted between two clock edges : the flags and
  -- fill levels are those of an empty FIFO without clock edge ;
  -- after the release, the words written are read back (no stale
  -- word)
  procedure run
    (constant depth    : in    positive         -- DEPTH of the DUT
    ;signal   clk      : in    std_logic
    ;signal   arst_b   : out   std_logic
    ;signal   axis_s   : inout t_axistream_if   -- Write side (s_axis)
    ;signal   axis_m   : inout t_axistream_if   -- Read side (m_axis)
    ;signal   status   : in    status_t         -- Flags and fill levels
    );

end package tb_fifo_sync_async_reset_pkg;

package body tb_fifo_sync_async_reset_pkg is

  procedure run
    (constant depth    : in    positive         -- DEPTH of the DUT
    ;signal   clk      : in    std_logic
    ;signal   arst_b   : out   std_logic
    ;signal   axis_s   : inout t_axistream_if   -- Write side (s_axis)
    ;signal   axis_m   : inout t_axistream_if   -- Read side (m_axis)
    ;signal   status   : in    status_t         -- Flags and fill levels
    ) is
    variable model : model_t := model_empty(16#E0#);
  begin
    for i in 1 to depth loop
      cycle(model, true , false, "fill", depth, clk, axis_s, axis_m, status);
    end loop;
    cycle  (model, false, false, "full", depth, clk, axis_s, axis_m, status);
    idle(clk, axis_s, axis_m);
    -- Reset between two clock edges
    wait for C_CLK_PERIOD/4;
    arst_b <= '0';
    wait for 1 ns;
    chk_level(0, depth, "Reset without clock edge", axis_s, axis_m, status);
    wait until falling_edge(clk);
    arst_b <= '1';
    -- Empty, the next words differ from the words left in the RAM
    model  := model_empty(model.wr);
    for i in 1 to 2 loop
      cycle(model, true , false, "write after reset", depth, clk, axis_s, axis_m, status);
    end loop;
    while model.wr /= model.rd loop
      cycle(model, false, true , "read after reset" , depth, clk, axis_s, axis_m, status);
    end loop;
    cycle  (model, false, false, "empty"            , depth, clk, axis_s, axis_m, status);
    idle(clk, axis_s, axis_m);
  end procedure;

end package body tb_fifo_sync_async_reset_pkg;

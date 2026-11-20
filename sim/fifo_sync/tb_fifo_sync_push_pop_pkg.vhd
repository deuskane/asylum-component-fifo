-------------------------------------------------------------------------------
-- Title      : tb_fifo_sync_push_pop_pkg
-- Project    : Asylum
-------------------------------------------------------------------------------
-- File       : tb_fifo_sync_push_pop_pkg.vhd
-- Author     : Mathieu Rosiere
-------------------------------------------------------------------------------
-- Description: Scenario push_pop of tb_fifo_sync, from reset :
--              Simultaneous write and read at every fill level, 0 to DEPTH (one
--              isolated, then 4 back to back, then drain), each from reset,
--              the level reached by writes from empty, then (below DEPTH) by
--              one read from the level above ; flags, fill levels and data
--              checked on every cycle
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

package tb_fifo_sync_push_pop_pkg is

  -- Simultaneous write and read at every fill level, 0 to DEPTH (one
  -- isolated, then 4 back to back, then drain), each from reset,
  -- the level reached by writes from empty, then (below DEPTH) by
  -- one read from the level above ; flags, fill levels and data
  -- checked on every cycle
  procedure run
    (constant depth    : in    positive         -- DEPTH of the DUT
    ;signal   clk      : in    std_logic
    ;signal   arst_b   : out   std_logic
    ;signal   axis_s   : inout t_axistream_if   -- Write side (s_axis)
    ;signal   axis_m   : inout t_axistream_if   -- Read side (m_axis)
    ;signal   status   : in    status_t         -- Flags and fill levels
    );

end package tb_fifo_sync_push_pop_pkg;

package body tb_fifo_sync_push_pop_pkg is

  procedure run
    (constant depth    : in    positive         -- DEPTH of the DUT
    ;signal   clk      : in    std_logic
    ;signal   arst_b   : out   std_logic
    ;signal   axis_s   : inout t_axistream_if   -- Write side (s_axis)
    ;signal   axis_m   : inout t_axistream_if   -- Read side (m_axis)
    ;signal   status   : in    status_t         -- Flags and fill levels
    ) is
    variable model : model_t := model_empty(16#20#);
  begin
    for from_above in 0 to 1 loop
      for level in 0 to depth - from_above loop
        -- From reset : the words go on from the previous level
        do_reset(clk, arst_b);
        model := model_empty(model.wr);
        -- Fill up to the level (or the level above, then one read)
        for i in 1 to level + from_above loop
          cycle(model, true , false, "level " & to_string(level) & ", from above " & to_string(from_above) & " : fill", depth, clk, axis_s, axis_m, status);
        end loop;
        if from_above = 1
        then
          cycle(model, false, true , "level " & to_string(level) & ", from above " & to_string(from_above) & " : read from above", depth, clk, axis_s, axis_m, status);
        end if;
        -- One isolated write and read (full : only the read is accepted)
        cycle  (model, true , true , "level " & to_string(level) & ", from above " & to_string(from_above) & " : write+read", depth, clk, axis_s, axis_m, status);
        cycle  (model, false, false, "level " & to_string(level) & ", from above " & to_string(from_above) & " : idle"      , depth, clk, axis_s, axis_m, status);
        -- Back to back writes and reads
        for i in 1 to 4 loop
          cycle(model, true , true , "level " & to_string(level) & ", from above " & to_string(from_above) & " : write+read burst " & to_string(i), depth, clk, axis_s, axis_m, status);
        end loop;
        -- Drain : order of the remaining words
        while model.wr /= model.rd loop
          cycle(model, false, true , "level " & to_string(level) & ", from above " & to_string(from_above) & " : drain", depth, clk, axis_s, axis_m, status);
        end loop;
        cycle  (model, false, false, "level " & to_string(level) & ", from above " & to_string(from_above) & " : empty", depth, clk, axis_s, axis_m, status);
        idle(clk, axis_s, axis_m);
      end loop;
    end loop;
  end procedure;

end package body tb_fifo_sync_push_pop_pkg;

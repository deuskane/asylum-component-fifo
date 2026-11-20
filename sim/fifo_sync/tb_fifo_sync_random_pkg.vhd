-------------------------------------------------------------------------------
-- Title      : tb_fifo_sync_random_pkg
-- Project    : Asylum
-------------------------------------------------------------------------------
-- File       : tb_fifo_sync_random_pkg.vhd
-- Author     : Mathieu Rosiere
-------------------------------------------------------------------------------
-- Description: Scenario random of tb_fifo_sync, from reset :
--              1200 cycles of random writes and reads in 4 profiles (balanced,
--              toward full, toward empty, busy), then drain ; flags, fill
--              levels and data checked on every cycle
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

package tb_fifo_sync_random_pkg is

  -- 1200 cycles of random writes and reads in 4 profiles (balanced,
  -- toward full, toward empty, busy), then drain ; flags, fill
  -- levels and data checked on every cycle
  procedure run
    (constant depth    : in    positive         -- DEPTH of the DUT
    ;signal   clk      : in    std_logic
    ;signal   axis_s   : inout t_axistream_if   -- Write side (s_axis)
    ;signal   axis_m   : inout t_axistream_if   -- Read side (m_axis)
    ;signal   status   : in    status_t         -- Flags and fill levels
    );

end package tb_fifo_sync_random_pkg;

package body tb_fifo_sync_random_pkg is

  procedure run
    (constant depth    : in    positive         -- DEPTH of the DUT
    ;signal   clk      : in    std_logic
    ;signal   axis_s   : inout t_axistream_if   -- Write side (s_axis)
    ;signal   axis_m   : inout t_axistream_if   -- Read side (m_axis)
    ;signal   status   : in    status_t         -- Flags and fill levels
    ) is
    variable model     : model_t := model_empty(16#80#);
    variable push_prob : natural;
    variable pop_prob  : natural;
  begin
    for phase in 0 to 3 loop
      case phase is
        when 0      => push_prob := 50; pop_prob := 50;
        when 1      => push_prob := 80; pop_prob := 30; -- Toward full
        when 2      => push_prob := 30; pop_prob := 80; -- Toward empty
        when others => push_prob := 70; pop_prob := 70;
      end case;
      for i in 1 to 300 loop
        cycle(model, random(1, 100) <= push_prob, random(1, 100) <= pop_prob,
              "phase " & to_string(phase) & " cycle " & to_string(i), depth, clk, axis_s, axis_m, status);
      end loop;
    end loop;
    while model.wr /= model.rd loop
      cycle(model, false, true , "drain", depth, clk, axis_s, axis_m, status);
    end loop;
    cycle  (model, false, false, "empty", depth, clk, axis_s, axis_m, status);
    idle(clk, axis_s, axis_m);
    log(ID_SEQUENCER, to_string(model.wr) & " words transferred", C_TB_SCOPE);
  end procedure;

end package body tb_fifo_sync_random_pkg;

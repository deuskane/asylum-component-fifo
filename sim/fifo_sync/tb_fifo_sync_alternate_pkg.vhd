-------------------------------------------------------------------------------
-- Title      : tb_fifo_sync_alternate_pkg
-- Project    : Asylum
-------------------------------------------------------------------------------
-- File       : tb_fifo_sync_alternate_pkg.vhd
-- Author     : Mathieu Rosiere
-------------------------------------------------------------------------------
-- Description: Scenario alternate of tb_fifo_sync, from reset :
--              2 x DEPTH pairs of one write and one read (AXI-Stream BFM) : the FIFO
--              goes from empty to one word and back
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

package tb_fifo_sync_alternate_pkg is

  -- 2 x DEPTH pairs of one write and one read (AXI-Stream BFM) : the FIFO
  -- goes from empty to one word and back
  procedure run
    (constant depth    : in    positive         -- DEPTH of the DUT
    ;signal   clk      : in    std_logic
    ;signal   axis_s   : inout t_axistream_if   -- Write side (s_axis)
    ;signal   axis_m   : inout t_axistream_if   -- Read side (m_axis)
    ;signal   status   : in    status_t         -- Flags and fill levels
    );

end package tb_fifo_sync_alternate_pkg;

package body tb_fifo_sync_alternate_pkg is

  procedure run
    (constant depth    : in    positive         -- DEPTH of the DUT
    ;signal   clk      : in    std_logic
    ;signal   axis_s   : inout t_axistream_if   -- Write side (s_axis)
    ;signal   axis_m   : inout t_axistream_if   -- Read side (m_axis)
    ;signal   status   : in    status_t         -- Flags and fill levels
    ) is
  begin
    for i in 1 to 2*depth loop
      push(word(16#50#+i), "Write data " & to_string(i), clk, axis_s);
      pop (word(16#50#+i), "Read data "  & to_string(i), clk, axis_m);
    end loop;
  end procedure;

end package body tb_fifo_sync_alternate_pkg;

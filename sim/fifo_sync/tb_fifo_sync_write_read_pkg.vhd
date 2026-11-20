-------------------------------------------------------------------------------
-- Title      : tb_fifo_sync_write_read_pkg
-- Project    : Asylum
-------------------------------------------------------------------------------
-- File       : tb_fifo_sync_write_read_pkg.vhd
-- Author     : Mathieu Rosiere
-------------------------------------------------------------------------------
-- Description: Scenario write_read of tb_fifo_sync, from reset :
--              min(5, DEPTH) words written, then read in order (AXI-Stream BFM)
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

package tb_fifo_sync_write_read_pkg is

  -- min(5, DEPTH) words written, then read in order (AXI-Stream BFM)
  procedure run
    (constant depth    : in    positive         -- DEPTH of the DUT
    ;signal   clk      : in    std_logic
    ;signal   axis_s   : inout t_axistream_if   -- Write side (s_axis)
    ;signal   axis_m   : inout t_axistream_if   -- Read side (m_axis)
    ;signal   status   : in    status_t         -- Flags and fill levels
    );

end package tb_fifo_sync_write_read_pkg;

package body tb_fifo_sync_write_read_pkg is

  procedure run
    (constant depth    : in    positive         -- DEPTH of the DUT
    ;signal   clk      : in    std_logic
    ;signal   axis_s   : inout t_axistream_if   -- Write side (s_axis)
    ;signal   axis_m   : inout t_axistream_if   -- Read side (m_axis)
    ;signal   status   : in    status_t         -- Flags and fill levels
    ) is
  begin
    for i in 1 to minimum(5, depth) loop
      push(word(16#30#+i), "Write data " & to_string(i), clk, axis_s);
    end loop;
    for i in 1 to minimum(5, depth) loop
      pop (word(16#30#+i), "Read data "  & to_string(i), clk, axis_m);
    end loop;
  end procedure;

end package body tb_fifo_sync_write_read_pkg;

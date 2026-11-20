-------------------------------------------------------------------------------
-- Title      : tb_fifo_sync_fill_drain_pkg
-- Project    : Asylum
-------------------------------------------------------------------------------
-- File       : tb_fifo_sync_fill_drain_pkg.vhd
-- Author     : Mathieu Rosiere
-------------------------------------------------------------------------------
-- Description: Scenario fill_drain of tb_fifo_sync, from reset :
--              DEPTH words written (the FIFO is full : flags and fill levels), then
--              read in order (AXI-Stream BFM), the FIFO is empty again
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

package tb_fifo_sync_fill_drain_pkg is

  -- DEPTH words written (the FIFO is full : flags and fill levels), then
  -- read in order (AXI-Stream BFM), the FIFO is empty again
  procedure run
    (constant depth    : in    positive         -- DEPTH of the DUT
    ;signal   clk      : in    std_logic
    ;signal   axis_s   : inout t_axistream_if   -- Write side (s_axis)
    ;signal   axis_m   : inout t_axistream_if   -- Read side (m_axis)
    ;signal   status   : in    status_t         -- Flags and fill levels
    );

end package tb_fifo_sync_fill_drain_pkg;

package body tb_fifo_sync_fill_drain_pkg is

  procedure run
    (constant depth    : in    positive         -- DEPTH of the DUT
    ;signal   clk      : in    std_logic
    ;signal   axis_s   : inout t_axistream_if   -- Write side (s_axis)
    ;signal   axis_m   : inout t_axistream_if   -- Read side (m_axis)
    ;signal   status   : in    status_t         -- Flags and fill levels
    ) is
  begin
    for i in 1 to depth loop
      push(word(i+10), "Write data " & to_string(i+10), clk, axis_s);
    end loop;
    wait until falling_edge(clk);
    chk_level(depth, depth, "Full", axis_s, axis_m, status);
    for i in 1 to depth loop
      pop (word(i+10), "Read data "  & to_string(i+10), clk, axis_m);
    end loop;
    wait until falling_edge(clk);
    chk_level(0, depth, "Empty after the drain", axis_s, axis_m, status);
  end procedure;

end package body tb_fifo_sync_fill_drain_pkg;

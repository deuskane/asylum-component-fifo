-------------------------------------------------------------------------------
-- Title      : tb_fifo_sync_half_full_pkg
-- Project    : Asylum
-------------------------------------------------------------------------------
-- File       : tb_fifo_sync_half_full_pkg.vhd
-- Author     : Mathieu Rosiere
-------------------------------------------------------------------------------
-- Description: Scenario half_full of tb_fifo_sync, from reset :
--              DEPTH/2 words written, then DEPTH pairs of one write and one read,
--              then the last DEPTH/2 words read (AXI-Stream BFM) ; DEPTH >= 2
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

package tb_fifo_sync_half_full_pkg is

  -- DEPTH/2 words written, then DEPTH pairs of one write and one read,
  -- then the last DEPTH/2 words read (AXI-Stream BFM) ; DEPTH >= 2
  procedure run
    (constant depth    : in    positive         -- DEPTH of the DUT
    ;signal   clk      : in    std_logic
    ;signal   axis_s   : inout t_axistream_if   -- Write side (s_axis)
    ;signal   axis_m   : inout t_axistream_if   -- Read side (m_axis)
    ;signal   status   : in    status_t         -- Flags and fill levels
    );

end package tb_fifo_sync_half_full_pkg;

package body tb_fifo_sync_half_full_pkg is

  procedure run
    (constant depth    : in    positive         -- DEPTH of the DUT
    ;signal   clk      : in    std_logic
    ;signal   axis_s   : inout t_axistream_if   -- Write side (s_axis)
    ;signal   axis_m   : inout t_axistream_if   -- Read side (m_axis)
    ;signal   status   : in    status_t         -- Flags and fill levels
    ) is
  begin
    if depth < 2
    then
      alert(TB_ERROR, "half_full needs DEPTH >= 2", C_TB_SCOPE);
      return;
    end if;
    for i in 1 to depth/2 loop
      push(word(i+100), "Pre-fill " & to_string(i+100), clk, axis_s);
    end loop;
    for i in 1 to depth loop
      push(word(i+100+depth/2), "Write data " & to_string(i+100+depth/2), clk, axis_s);
      pop (word(i+100)        , "Read data "  & to_string(i+100)        , clk, axis_m);
    end loop;
    for i in 1 to depth/2 loop
      pop (word(i+100+depth)  , "Read data "  & to_string(i+100+depth)  , clk, axis_m);
    end loop;
  end procedure;

end package body tb_fifo_sync_half_full_pkg;

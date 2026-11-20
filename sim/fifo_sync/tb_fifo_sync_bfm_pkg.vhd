-------------------------------------------------------------------------------
-- Title      : tb_fifo_sync_bfm_pkg
-- Project    : Asylum
-------------------------------------------------------------------------------
-- File       : tb_fifo_sync_bfm_pkg.vhd
-- Author     : Mathieu Rosiere
-------------------------------------------------------------------------------
-- Description: Helpers of the tb_fifo_sync scenarios :
--              - word transfers with the UVVM AXI-Stream BFM (push, pop)
--              - cycle accurate transfers (cycle) : handshakes driven on the
--                falling edge, every output of the DUT checked against a
--                model of the FIFO (number of words written and read, the
--                n-th word written is word(n))
--              - reset pulse
-------------------------------------------------------------------------------
-- Copyright (c) 2026
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author   Description
-- 2026-11-20  1.0      mrosiere Created (from fifo_sync_tb)
-------------------------------------------------------------------------------

library ieee;
use     ieee.std_logic_1164.all;
use     ieee.numeric_std.all;

library uvvm_util;
context uvvm_util.uvvm_util_context;

library bitvis_vip_axistream;
use     bitvis_vip_axistream.axistream_bfm_pkg.all;

package tb_fifo_sync_bfm_pkg is

  constant C_TB_SCOPE    : string  := "TB_FIFO_BFM";
  constant C_CLK_PERIOD  : time    := 10 ns;
  constant C_WIDTH       : natural := 8;

  subtype  byte_t is std_logic_vector(C_WIDTH-1 downto 0);

  -- Flags and fill levels of the DUT
  type status_t is record
    s_nb_elt_empty : std_logic_vector;  -- s_axis_nb_elt_empty_o
    s_full         : std_logic;         -- s_axis_full_o
    s_empty        : std_logic;         -- s_axis_empty_o
    m_nb_elt_full  : std_logic_vector;  -- m_axis_nb_elt_full_o
    m_full         : std_logic;         -- m_axis_full_o
    m_empty        : std_logic;         -- m_axis_empty_o
  end record status_t;

  -- Model of the FIFO : the words word(rd) to word(wr-1) are stored, the
  -- next word written is word(wr)
  type model_t is record
    wr             : natural;
    rd             : natural;
  end record model_t;

  -- Model of an empty FIFO, next word written word(n) : each scenario (and
  -- each part of a scenario after a reset) starts at its own n, so that a
  -- word left in the RAM never equals an expected word
  function model_empty
    (constant n        : in    natural
    ) return model_t;

  -- AXI-Stream BFM
  constant C_AXIS_CFG    : t_axistream_bfm_config := C_AXISTREAM_BFM_CONFIG_DEFAULT;

  -- Word n of a sequence
  function word
    (constant n        : in    natural
    ) return byte_t;

  -- Write one word (AXI-Stream BFM)
  procedure push
    (constant data     : in    byte_t
    ;constant msg      : in    string
    ;signal   clk      : in    std_logic
    ;signal   axis_s   : inout t_axistream_if
    );

  -- Read one word and check it (AXI-Stream BFM)
  procedure pop
    (constant data     : in    byte_t
    ;constant msg      : in    string
    ;signal   clk      : in    std_logic
    ;signal   axis_m   : inout t_axistream_if
    );

  -- Check the flags and fill levels of a FIFO holding level words
  procedure chk_level
    (constant level    : in    natural
    ;constant depth    : in    positive
    ;constant msg      : in    string
    ;signal   axis_s   : in    t_axistream_if
    ;signal   axis_m   : in    t_axistream_if
    ;signal   status   : in    status_t
    );

  -- One clock cycle, cycle accurate : push_en / pop_en driven on the falling edge,
  -- flags, fill levels and head word (when not empty) checked against the
  -- model a quarter period later, model updated with the transfers of the
  -- next rising edge
  procedure cycle
    (variable model    : inout model_t
    ;constant push_en  : in    boolean
    ;constant pop_en   : in    boolean
    ;constant msg      : in    string
    ;constant depth    : in    positive
    ;signal   clk      : in    std_logic
    ;signal   axis_s   : inout t_axistream_if
    ;signal   axis_m   : inout t_axistream_if
    ;signal   status   : in    status_t
    );

  -- Release the handshakes after cycle, on a falling edge
  procedure idle
    (signal   clk      : in    std_logic
    ;signal   axis_s   : inout t_axistream_if
    ;signal   axis_m   : inout t_axistream_if
    );

  -- Reset pulse, released on a falling edge
  procedure do_reset
    (signal   clk      : in    std_logic
    ;signal   arst_b   : out   std_logic
    );

end package tb_fifo_sync_bfm_pkg;

package body tb_fifo_sync_bfm_pkg is

  function to_sl
    (constant b        : in    boolean
    ) return std_logic is
  begin
    if b
    then
      return '1';
    else
      return '0';
    end if;
  end function;

  function model_empty
    (constant n        : in    natural
    ) return model_t is
  begin
    return (wr => n, rd => n);
  end function;

  function word
    (constant n        : in    natural
    ) return byte_t is
  begin
    return std_logic_vector(to_unsigned(n mod 2**C_WIDTH, C_WIDTH));
  end function;

  procedure push
    (constant data     : in    byte_t
    ;constant msg      : in    string
    ;signal   clk      : in    std_logic
    ;signal   axis_s   : inout t_axistream_if
    ) is
  begin
    axistream_transmit(data_array   => data
                      ,msg          => msg
                      ,clk          => clk
                      ,axistream_if => axis_s
                      ,scope        => C_TB_SCOPE
                      ,config       => C_AXIS_CFG
                      );
  end procedure;

  procedure pop
    (constant data     : in    byte_t
    ;constant msg      : in    string
    ;signal   clk      : in    std_logic
    ;signal   axis_m   : inout t_axistream_if
    ) is
  begin
    axistream_expect(exp_data_array => data
                    ,msg            => msg
                    ,clk            => clk
                    ,axistream_if   => axis_m
                    ,alert_level    => error
                    ,scope          => C_TB_SCOPE
                    ,config         => C_AXIS_CFG
                    );
  end procedure;

  procedure chk_level
    (constant level    : in    natural
    ;constant depth    : in    positive
    ;constant msg      : in    string
    ;signal   axis_s   : in    t_axistream_if
    ;signal   axis_m   : in    t_axistream_if
    ;signal   status   : in    status_t
    ) is
  begin
    check_value(status.m_nb_elt_full , std_logic_vector(to_unsigned(level      , status.m_nb_elt_full 'length)), error, msg & " : m_axis_nb_elt_full_o" , C_TB_SCOPE);
    check_value(status.s_nb_elt_empty, std_logic_vector(to_unsigned(depth-level, status.s_nb_elt_empty'length)), error, msg & " : s_axis_nb_elt_empty_o", C_TB_SCOPE);
    check_value(axis_m.tvalid , to_sl(level /= 0    ), error, msg & " : m_axis_tvalid_o", C_TB_SCOPE);
    check_value(axis_s.tready , to_sl(level /= depth), error, msg & " : s_axis_tready_o", C_TB_SCOPE);
    check_value(status.s_empty, to_sl(level  = 0    ), error, msg & " : s_axis_empty_o" , C_TB_SCOPE);
    check_value(status.m_empty, to_sl(level  = 0    ), error, msg & " : m_axis_empty_o" , C_TB_SCOPE);
    check_value(status.s_full , to_sl(level  = depth), error, msg & " : s_axis_full_o"  , C_TB_SCOPE);
    check_value(status.m_full , to_sl(level  = depth), error, msg & " : m_axis_full_o"  , C_TB_SCOPE);
  end procedure;

  procedure cycle
    (variable model    : inout model_t
    ;constant push_en  : in    boolean
    ;constant pop_en   : in    boolean
    ;constant msg      : in    string
    ;constant depth    : in    positive
    ;signal   clk      : in    std_logic
    ;signal   axis_s   : inout t_axistream_if
    ;signal   axis_m   : inout t_axistream_if
    ;signal   status   : in    status_t
    ) is
    variable level     : natural;
    variable push_ok   : boolean;
    variable pop_ok    : boolean;
  begin
    level   := model.wr - model.rd;

    wait until falling_edge(clk);
    axis_s.tvalid <= to_sl(push_en);
    -- A write refused (full) carries another word than the next accepted one
    if level = depth
    then
      axis_s.tdata <= not word(model.wr);
    else
      axis_s.tdata <= word(model.wr);
    end if;
    axis_m.tready <= to_sl(pop_en);
    wait for C_CLK_PERIOD/4;
    push_ok := push_en and level /= depth;
    pop_ok  := pop_en  and level /= 0;

    chk_level(level, depth, msg, axis_s, axis_m, status);

    -- Head word : presented as long as the FIFO is not empty, popped or not
    if level /= 0
    then
      check_value(axis_m.tdata, word(model.rd), error,
                  msg & " : m_axis_tdata_o (word #" & to_string(model.rd) & ", level " & to_string(level) & ", pop " & to_string(pop_ok) & ", push " & to_string(push_ok) & ")", C_TB_SCOPE);
    end if;

    if pop_ok
    then
      model.rd := model.rd + 1;
    end if;

    if push_ok
    then
      model.wr := model.wr + 1;
    end if;

    wait until rising_edge(clk);
  end procedure;

  procedure idle
    (signal   clk      : in    std_logic
    ;signal   axis_s   : inout t_axistream_if
    ;signal   axis_m   : inout t_axistream_if
    ) is
  begin
    wait until falling_edge(clk);
    axis_s.tvalid <= '0';
    axis_m.tready <= '0';
  end procedure;

  procedure do_reset
    (signal   clk      : in    std_logic
    ;signal   arst_b   : out   std_logic
    ) is
  begin
    arst_b <= '0';
    wait for 100 ns;
    wait until falling_edge(clk);
    arst_b <= '1';
    wait until rising_edge(clk);
  end procedure;

end package body tb_fifo_sync_bfm_pkg;

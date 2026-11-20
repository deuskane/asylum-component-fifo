-------------------------------------------------------------------------------
-- Title      : tb_fifo_sync
-- Project    : Asylum
-------------------------------------------------------------------------------
-- File       : tb_fifo_sync.vhd
-- Author     : mrosiere
-------------------------------------------------------------------------------
-- Description: UVVM self-checking testbench of fifo_sync (8-bit words)
--              TESTS_LIST : scenarios run in sequence, separated by ','
--                           (tb_fifo_sync_tests_pkg), each one after a
--                           reset pulse ; "" : build and elaboration only
--              DEPTH      : DEPTH of the DUT
--              SYNC_READ  : SYNC_READ of the DUT
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author   Description
-- 2026-06-10  1.0      mrosiere Created
-- 2026-10-05  1.1      mrosiere Add simultaneous push/pop at every fill level,
--                               random push/pop and status flag checks
-- 2026-10-05  1.2      mrosiere DEPTH generic (DEPTH = 1 regression)
-- 2026-11-20  2.0      mrosiere TESTS_LIST, one package per scenario
--                               (tb_fifo_sync_<name>_pkg), helpers in
--                               tb_fifo_sync_bfm_pkg, reset pulse before each
--                               scenario (was fifo_sync_tb)
-------------------------------------------------------------------------------

library ieee;
use     ieee.std_logic_1164.all;
use     ieee.numeric_std.all;

library uvvm_util;
context uvvm_util.uvvm_util_context;

library bitvis_vip_axistream;
use     bitvis_vip_axistream.axistream_bfm_pkg.all;

library asylum;
use     asylum.math_pkg.all;
use     asylum.string_pkg.all;
use     asylum.fifo_pkg.all;

library work;
use     work.tb_fifo_sync_bfm_pkg.all;
use     work.tb_fifo_sync_tests_pkg.all;

entity tb_fifo_sync is
  generic (
    TESTS_LIST       : string   := ""     -- Scenarios, e.g. "write_read,push_pop"
   ;DEPTH            : positive := 8      -- FIFO depth (power of 2)
   ;SYNC_READ        : boolean  := true   -- true : synchronous RAM read
  );
end entity tb_fifo_sync;

architecture sim of tb_fifo_sync is

  constant C_SCOPE         : string  := "TB_FIFO_SYNC";

  signal   clk_i           : std_logic := '0';
  signal   clk_ena         : boolean   := true;
  signal   arst_b_i        : std_logic := '0';

  -- AXI-Stream BFM : write side (BFM master) and read side (BFM slave)
  signal   axis_s          : t_axistream_if(tdata(C_WIDTH-1 downto 0), tkeep(0 downto 0), tuser(0 downto 0),
                                            tstrb(0 downto 0), tid(0 downto 0), tdest(0 downto 0));
  signal   axis_m          : t_axistream_if(tdata(C_WIDTH-1 downto 0), tkeep(0 downto 0), tuser(0 downto 0),
                                            tstrb(0 downto 0), tid(0 downto 0), tdest(0 downto 0));

  signal   status          : status_t(s_nb_elt_empty(clog2(DEPTH) downto 0),
                                      m_nb_elt_full (clog2(DEPTH) downto 0));

begin

  clock_generator(clk_i, clk_ena, C_CLK_PERIOD, "TB Clock");

  -----------------------------------------------------------------------------
  -- DUT
  -----------------------------------------------------------------------------
  dut : fifo_sync
    generic map
    (WIDTH                 => C_WIDTH
    ,DEPTH                 => DEPTH
    ,SYNC_READ             => SYNC_READ
    )
    port map
    (clk_i                 => clk_i
    ,arst_b_i              => arst_b_i
    ,s_axis_tvalid_i       => axis_s.tvalid
    ,s_axis_tready_o       => axis_s.tready
    ,s_axis_tdata_i        => axis_s.tdata
    ,s_axis_nb_elt_empty_o => status.s_nb_elt_empty
    ,s_axis_full_o         => status.s_full
    ,s_axis_empty_o        => status.s_empty
    ,m_axis_tvalid_o       => axis_m.tvalid
    ,m_axis_tready_i       => axis_m.tready
    ,m_axis_tdata_o        => axis_m.tdata
    ,m_axis_nb_elt_full_o  => status.m_nb_elt_full
    ,m_axis_full_o         => status.m_full
    ,m_axis_empty_o        => status.m_empty
    );

  -- No tkeep on the read side : every byte valid
  axis_m.tkeep <= (others => '1');

  -----------------------------------------------------------------------------
  -- Sequencer
  -----------------------------------------------------------------------------
  p_sequencer : process
  begin
    log(ID_LOG_HDR, "DEPTH = " & to_string(DEPTH) & ", SYNC_READ = " & to_string(SYNC_READ) & ", TESTS_LIST : " & TESTS_LIST, C_SCOPE);

    -- Every name is checked before the first scenario
    for i in 1 to list_length(TESTS_LIST) loop
      if not list_contains(C_TESTS, list_item(TESTS_LIST, i))
      then
        alert(TB_ERROR, "Unknown test """ & list_item(TESTS_LIST, i) & """ (tests : " & C_TESTS & ")", C_SCOPE);
      end if;
    end loop;

    for i in 1 to list_length(TESTS_LIST) loop
      -- Reset pulse, handshakes inactive : each scenario starts from reset
      axis_s <= init_axistream_if_signals(true , C_WIDTH, 1, 1, 1);
      axis_m <= init_axistream_if_signals(false, C_WIDTH, 1, 1, 1);
      do_reset(clk_i, arst_b_i);

      log(ID_LOG_HDR, "TEST " & integer'image(i) & "/" & integer'image(list_length(TESTS_LIST)) & " : " & list_item(TESTS_LIST, i), C_SCOPE);
      run_test(list_item(TESTS_LIST, i), DEPTH, clk_i, arst_b_i, axis_s, axis_m, status);
    end loop;

    report_alert_counters(FINAL);
    std.env.stop;
    wait;
  end process p_sequencer;

end architecture sim;

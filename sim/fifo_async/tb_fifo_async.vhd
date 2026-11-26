-------------------------------------------------------------------------------
-- Title      : tb_fifo_async
-- Project    : FIFO
-------------------------------------------------------------------------------
-- File       : tb_fifo_async.vhd
-- Author     : mrosiere
-------------------------------------------------------------------------------
-- Description: Self-checking UVVM testbench of fifo_async (8-bit words) :
--              AXI-Stream BFM master on the write side (s_clk), slave on
--              the read side (m_clk).
--              TESTS_LIST   : scenarios run in sequence, separated by ','
--                             (tb_fifo_async_tests_pkg), each one after a
--                             reset pulse ; "" : build and elaboration only
--              DEPTH        : generic of the DUT (power of 2)
--              S_CLK_PERIOD, M_CLK_PERIOD : periods of the write and read
--                             clocks, in ns (unrelated : e.g. 10 and 13)
--              Clock enables (ena) : a scenario may stop a clock.
--              Monitor : time of the last transfer of each side and of the
--              last rise of s_axis_tready_o / m_axis_tvalid_o (latency of
--              the synchronizers).
-------------------------------------------------------------------------------
-- Copyright (c) 2026
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author   Description
-- 2026-11-26  1.0      mrosiere Created
-------------------------------------------------------------------------------

library ieee;
use     ieee.std_logic_1164.all;
use     ieee.numeric_std.all;

library uvvm_util;
context uvvm_util.uvvm_util_context;

library bitvis_vip_axistream;
use     bitvis_vip_axistream.axistream_bfm_pkg.all;

library asylum;
use     asylum.string_pkg.all;
use     asylum.fifo_pkg.all;

library work;
use     work.tb_fifo_sync_bfm_pkg.all;
use     work.tb_fifo_async_bfm_pkg.all;
use     work.tb_fifo_async_tests_pkg.all;

entity tb_fifo_async is
  generic (
    TESTS_LIST       : string  := ""      -- Scenarios, e.g. "write_read,stream"
   ;DEPTH            : natural := 8       -- FIFO depth (power of 2)
   ;S_CLK_PERIOD     : natural := 10      -- Period of the write clock, ns
   ;M_CLK_PERIOD     : natural := 13      -- Period of the read clock, ns
  );
end entity tb_fifo_async;

architecture sim of tb_fifo_async is

  constant C_SCOPE         : string   := "TB_FIFO_ASYNC";
  constant C_AW            : natural  := asylum.math_pkg.clog2(DEPTH);
  constant C_CFG           : tb_cfg_t := (depth    => DEPTH
                                         ,s_period => S_CLK_PERIOD * 1 ns
                                         ,m_period => M_CLK_PERIOD * 1 ns);

  signal   s_clk           : std_logic := '0';
  signal   m_clk           : std_logic := '0';
  signal   ena             : tb_ena_t  := (s => true, m => true);
  signal   arst_b          : std_logic := '0';

  -- AXI-Stream BFM : write side (BFM master) and read side (BFM slave)
  signal   axis_s          : t_axistream_if(tdata(C_WIDTH-1 downto 0), tkeep(0 downto 0), tuser(0 downto 0),
                                            tstrb(0 downto 0), tid(0 downto 0), tdest(0 downto 0));
  signal   axis_m          : t_axistream_if(tdata(C_WIDTH-1 downto 0), tkeep(0 downto 0), tuser(0 downto 0),
                                            tstrb(0 downto 0), tid(0 downto 0), tdest(0 downto 0));

  signal   status          : status_t(s_nb_elt_empty(C_AW downto 0),
                                      m_nb_elt_full (C_AW downto 0));
  signal   xfer            : tb_xfer_t := (others => 0 ns);

begin

  clock_generator(s_clk, ena.s, S_CLK_PERIOD * 1 ns, "TB write clock");
  clock_generator(m_clk, ena.m, M_CLK_PERIOD * 1 ns, "TB read clock");

  -----------------------------------------------------------------------------
  -- DUT
  -----------------------------------------------------------------------------
  dut : fifo_async
    generic map
    (WIDTH                 => C_WIDTH
    ,DEPTH                 => DEPTH
    )
    port map
    (arst_b_i              => arst_b
    ,s_clk_i               => s_clk
    ,s_axis_tvalid_i       => axis_s.tvalid
    ,s_axis_tready_o       => axis_s.tready
    ,s_axis_tdata_i        => axis_s.tdata
    ,s_axis_nb_elt_empty_o => status.s_nb_elt_empty
    ,s_axis_full_o         => status.s_full
    ,s_axis_empty_o        => status.s_empty
    ,m_clk_i               => m_clk
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
  -- Monitor : times of the transfers and of the rises of tready / tvalid
  -----------------------------------------------------------------------------
  p_s_monitor : process (s_clk, axis_s.tready)
  begin
    if rising_edge(s_clk) and axis_s.tvalid = '1' and axis_s.tready = '1'
    then
      xfer.s_time      <= now;
    end if;
    if rising_edge(axis_s.tready)
    then
      xfer.tready_rise <= now;
    end if;
  end process p_s_monitor;

  p_m_monitor : process (m_clk, axis_m.tvalid)
  begin
    if rising_edge(m_clk) and axis_m.tvalid = '1' and axis_m.tready = '1'
    then
      xfer.m_time      <= now;
    end if;
    if rising_edge(axis_m.tvalid)
    then
      xfer.tvalid_rise <= now;
    end if;
  end process p_m_monitor;

  -----------------------------------------------------------------------------
  -- Sequencer
  -----------------------------------------------------------------------------
  p_sequencer : process
  begin
    log(ID_LOG_HDR, "DEPTH = " & to_string(DEPTH) & ", write clock " & to_string(S_CLK_PERIOD) & " ns, read clock " &
        to_string(M_CLK_PERIOD) & " ns, TESTS_LIST : " & TESTS_LIST, C_SCOPE);

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
      ena    <= (s => true, m => true);
      do_reset(C_CFG, s_clk, arst_b);

      log(ID_LOG_HDR, "TEST " & integer'image(i) & "/" & integer'image(list_length(TESTS_LIST)) & " : " & list_item(TESTS_LIST, i), C_SCOPE);
      run_test(list_item(TESTS_LIST, i), C_CFG, s_clk, m_clk, arst_b, axis_s, axis_m, status, xfer, ena);
    end loop;

    settle(C_CFG);
    report_alert_counters(FINAL);
    std.env.stop;
    wait;
  end process p_sequencer;

end architecture sim;

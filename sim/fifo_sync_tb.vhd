-------------------------------------------------------------------------------
-- Title      : fifo_sync_tb
-- Project    : Asylum
-------------------------------------------------------------------------------
-- File       : fifo_sync_tb.vhd
-- Author     : mrosiere
-------------------------------------------------------------------------------
-- Description: UVVM testbench of fifo_sync (AXI-Stream BFM + cycle accurate
--              scoreboard for simultaneous push / pop)
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author   Description
-- 2026-06-10  1.0      mrosiere Created
-- 2026-10-05  1.1      mrosiere Add simultaneous push/pop at every fill level,
--                               random push/pop and status flag checks
-- 2026-10-05  1.2      mrosiere DEPTH generic (DEPTH = 1 regression)
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


library asylum;
use     asylum.fifo_pkg.all;
use     asylum.math_pkg.clog2;

library uvvm_util;
context uvvm_util.uvvm_util_context;

library bitvis_vip_axistream;
use bitvis_vip_axistream.axistream_bfm_pkg.all;

entity fifo_sync_tb is
  generic (
    SYNC_READ : boolean := false; -- true: synchronous read, false: asynchronous read
    DEPTH     : positive := 16      -- FIFO depth (power of 2)
  );
end entity;

architecture func of fifo_sync_tb is
  constant C_WIDTH      : natural := 8;
  constant C_DEPTH      : natural := DEPTH;
  constant C_CLK_PERIOD : time    := 10 ns;

  signal clk            : std_logic := '0';
  signal arst_b         : std_logic := '0';

  -- Signaux AXI-Stream
  signal s_axis_tvalid  : std_logic;
  signal s_axis_tready  : std_logic;
  signal s_axis_tdata   : std_logic_vector(C_WIDTH-1 downto 0);
  
  signal m_axis_tvalid  : std_logic;
  signal m_axis_tready  : std_logic;
  signal m_axis_tdata   : std_logic_vector(C_WIDTH-1 downto 0);

  -- Status outputs
  signal s_axis_nb_elt_empty : std_logic_vector(clog2(C_DEPTH) downto 0);
  signal s_axis_full    : std_logic;
  signal s_axis_empty   : std_logic;
  signal m_axis_nb_elt_full  : std_logic_vector(clog2(C_DEPTH) downto 0);
  signal m_axis_full    : std_logic;
  signal m_axis_empty   : std_logic;

  -- UVVM AXI-Stream Interfaces
  signal axistream_if_s : t_axistream_if(tdata(C_WIDTH-1 downto 0), tkeep(0 downto 0), tuser(0 downto 0), tstrb(0 downto 0), tid(0 downto 0), tdest(0 downto 0));
  signal axistream_if_m : t_axistream_if(tdata(C_WIDTH-1 downto 0), tkeep(0 downto 0), tuser(0 downto 0), tstrb(0 downto 0), tid(0 downto 0), tdest(0 downto 0));


  procedure p_reset(signal arst_b : out std_logic) is
  begin
    arst_b <= '0';
    wait for 100 ns;
    arst_b <= '1';
  end procedure;
  
begin
  clk <= not clk after C_CLK_PERIOD / 2;

  DUT : fifo_sync
    generic map (
      WIDTH     => C_WIDTH,
      DEPTH     => C_DEPTH,
      SYNC_READ => SYNC_READ
    )
    port map (
      clk_i                 => clk,
      arst_b_i              => arst_b,
      s_axis_tvalid_i       => s_axis_tvalid,
      s_axis_tready_o       => s_axis_tready,
      s_axis_tdata_i        => s_axis_tdata,
      s_axis_nb_elt_empty_o => s_axis_nb_elt_empty,
      s_axis_full_o         => s_axis_full,
      s_axis_empty_o        => s_axis_empty,
      m_axis_tvalid_o       => m_axis_tvalid,
      m_axis_tready_i       => m_axis_tready,
      m_axis_tdata_o        => m_axis_tdata,
      m_axis_nb_elt_full_o  => m_axis_nb_elt_full,
      m_axis_full_o         => m_axis_full,
      m_axis_empty_o        => m_axis_empty
    );

  -- Mapping des interfaces VIP
  s_axis_tvalid         <= axistream_if_s.tvalid;
  axistream_if_s.tready <= s_axis_tready;
  s_axis_tdata          <= axistream_if_s.tdata(C_WIDTH-1 downto 0);

  m_axis_tready         <= axistream_if_m.tready;
  axistream_if_m.tvalid <= m_axis_tvalid;
  axistream_if_m.tdata(C_WIDTH-1 downto 0)  <= m_axis_tdata;
  axistream_if_m.tkeep  <= (others => '1');


  p_main : process
    variable v_data : std_logic_vector(C_WIDTH-1 downto 0);
    variable v_data_array : t_slv_array(0 to 0)(C_WIDTH-1 downto 0);
    variable v_len  : natural;
    variable v_user : t_user_array(0 to 0);
    variable v_strb : t_strb_array(0 to 0);
    variable v_id   : t_id_array(0 to 0);
    variable v_dest : t_dest_array(0 to 0);
    variable v_axistream_bfm_config : t_axistream_bfm_config := C_AXISTREAM_BFM_CONFIG_DEFAULT;

    -- Scoreboard: reference model of the FIFO content (circular buffer)
    type     t_model is array (0 to 255) of std_logic_vector(C_WIDTH-1 downto 0);
    variable v_model      : t_model;
    variable v_model_wr   : natural := 0; -- number of words accepted on the write side
    variable v_model_rd   : natural := 0; -- number of words accepted on the read  side
    variable v_next_data  : natural := 0; -- next value pushed
    variable v_push       : boolean;
    variable v_pop        : boolean;
    variable v_push_prob  : natural;
    variable v_pop_prob   : natural;
    variable v_nb_checks  : natural := 0; -- number of check_value done by cycle()

    function to_sl(b : boolean) return std_logic is
    begin
      if b then return '1'; else return '0'; end if;
    end function;

    -- Empty the scoreboard (after a reset of the DUT)
    procedure model_reset is
    begin
      v_model_wr  := 0;
      v_model_rd  := 0;
      v_next_data := 0;
    end procedure;

    -- One clock cycle with direct drive of the AXI-Stream handshakes.
    -- push/pop are driven on the falling edge, the DUT outputs are checked
    -- against the scoreboard a quarter period later, the transfers occur
    -- on the next rising edge.
    procedure cycle(constant push : in boolean;
                    constant pop  : in boolean;
                    constant msg  : in string) is
      variable v_level : natural;
      variable v_push_ok : boolean;
      variable v_pop_ok  : boolean;
    begin
      wait until falling_edge(clk);
      axistream_if_s.tvalid <= to_sl(push);
      axistream_if_s.tdata  <= std_logic_vector(to_unsigned(v_next_data mod 2**C_WIDTH, C_WIDTH));
      axistream_if_m.tready <= to_sl(pop);
      wait for C_CLK_PERIOD/4;

      v_level := v_model_wr - v_model_rd;

      -- Status flags against the model fill level
      check_value(to_integer(unsigned(m_axis_nb_elt_full )), v_level        , ERROR, msg & ": m_axis_nb_elt_full");
      check_value(to_integer(unsigned(s_axis_nb_elt_empty)), C_DEPTH-v_level, ERROR, msg & ": s_axis_nb_elt_empty");
      check_value(m_axis_tvalid, to_sl(v_level /= 0      ), ERROR, msg & ": m_axis_tvalid");
      check_value(s_axis_tready, to_sl(v_level /= C_DEPTH), ERROR, msg & ": s_axis_tready");
      check_value(s_axis_empty , to_sl(v_level  = 0      ), ERROR, msg & ": s_axis_empty");
      check_value(m_axis_empty , to_sl(v_level  = 0      ), ERROR, msg & ": m_axis_empty");
      check_value(s_axis_full  , to_sl(v_level  = C_DEPTH), ERROR, msg & ": s_axis_full");
      check_value(m_axis_full  , to_sl(v_level  = C_DEPTH), ERROR, msg & ": m_axis_full");

      v_nb_checks := v_nb_checks + 8;

      v_push_ok := push and s_axis_tready = '1';
      v_pop_ok  := pop  and m_axis_tvalid = '1';

      -- Data order: the word presented on the read side must be the oldest one
      if v_pop_ok then
        check_value(m_axis_tdata, v_model(v_model_rd mod t_model'length), ERROR,
                    msg & ": m_axis_tdata (word #" & to_string(v_model_rd) & ", level " & to_string(v_level) & ", push " & to_string(v_push_ok) & ")");
        v_model_rd  := v_model_rd  + 1;
        v_nb_checks := v_nb_checks + 1;
      end if;

      if v_push_ok then
        v_model(v_model_wr mod t_model'length) := std_logic_vector(to_unsigned(v_next_data mod 2**C_WIDTH, C_WIDTH));
        v_model_wr  := v_model_wr  + 1;
        v_next_data := v_next_data + 1;
      end if;

      wait until rising_edge(clk);
    end procedure;

    -- Release the handshakes after a direct drive sequence
    procedure cycle_idle is
    begin
      wait until falling_edge(clk);
      axistream_if_s.tvalid <= '0';
      axistream_if_m.tready <= '0';
    end procedure;
  begin
    log(ID_LOG_HDR, "Starting FIFO simulation: SYNC_READ = " & to_string(SYNC_READ));
    
    axistream_if_m.tready <= '0'; -- Always ready to receive
    log(ID_LOG_HDR, "Test 1: Simple write/read sequence");
    p_reset(arst_b);
    wait for 200 ns;

    for i in 1 to minimum(5, C_DEPTH) loop
      v_data := std_logic_vector(to_unsigned(i, C_WIDTH));
      axistream_transmit(v_data, "Sending data " & to_string(i), clk, axistream_if_s);
    end loop;

    for i in 1 to minimum(5, C_DEPTH) loop
      v_data := std_logic_vector(to_unsigned(i, C_WIDTH));
      axistream_expect(v_data, "Checking data " & to_string(i), clk, axistream_if_m);
    end loop;

    log(ID_LOG_HDR, "Test 2: Continuous flow and full buffer");
    p_reset(arst_b);
    wait for 200 ns;

    for i in 1 to C_DEPTH loop
      axistream_transmit(std_logic_vector(to_unsigned(i+10, C_WIDTH)), "Writing data " & to_string(i+10), clk, axistream_if_s);
    end loop;
    for i in 1 to C_DEPTH loop
      axistream_expect(std_logic_vector(to_unsigned(i+10, C_WIDTH)), "Reading data " & to_string(i+10), clk, axistream_if_m);
    end loop;

    log(ID_LOG_HDR, "Test 3: Parallel Push and Pop");
    p_reset(arst_b);
    wait for 200 ns;

    for i in 1 to C_DEPTH*2 loop
      -- Alternating or launching simultaneously via non-blocking procedures if supported,
      -- or simply chained to test pipeline dynamics.
      v_data := std_logic_vector(to_unsigned(i, C_WIDTH));
      axistream_transmit(v_data, "Parallel transmission " & to_string(i), clk, axistream_if_s);
      
      -- Expecting to receive data (possibly with a delay if SYNC_READ is true)
      axistream_expect(v_data, "Parallel reception " & to_string(i), clk, axistream_if_m);
    end loop;


    log(ID_LOG_HDR, "Test 4: Parallel Push and Pop with non-empty FIFO");
    p_reset(arst_b);
    wait for 200 ns;

    -- Fill FIFO halfway
    for i in 1 to C_DEPTH/2 loop
      axistream_transmit(std_logic_vector(to_unsigned(i+100, C_WIDTH)), "Pre-filling " & to_string(i), clk, axistream_if_s);
    end loop;

    -- Parallel push and pop
    for i in 1 to C_DEPTH loop
      v_data := std_logic_vector(to_unsigned(i+100+C_DEPTH/2, C_WIDTH));
      -- Push new data
      axistream_transmit(v_data, "Pushing " & to_string(i+100+C_DEPTH/2), clk, axistream_if_s);
      -- Pop old data (from the pre-fill)
      axistream_expect(std_logic_vector(to_unsigned(i+100, C_WIDTH)), "Popping pre-filled " & to_string(i+100), clk, axistream_if_m);
    end loop;

    for i in 1 to C_DEPTH/2 loop
      axistream_expect(std_logic_vector(to_unsigned(i+100+C_DEPTH, C_WIDTH)), "Popping pre-filled " & to_string(i+100+C_DEPTH), clk, axistream_if_m);    end loop;

    log(ID_LOG_HDR, "Test 5: Overflow condition");
    p_reset(arst_b);
    wait for 200 ns;

    -- Fill the FIFO
    for i in 1 to C_DEPTH loop
      axistream_transmit(std_logic_vector(to_unsigned(i, C_WIDTH)), "Filling for overflow", clk, axistream_if_s);
    end loop;

    -- Attempt one more write (should be blocked by tready). 
    -- We expect a timeout here, so we temporarily adjust the BFM config.
    -- Note: We use a short timeout to avoid long simulation time.
    v_axistream_bfm_config := C_AXISTREAM_BFM_CONFIG_DEFAULT;
    v_axistream_bfm_config.max_wait_cycles_severity := WARNING;

    increment_expected_alerts(WARNING, 1); -- Expect 1 timeout error
    axistream_transmit(std_logic_vector'(x"FF"), "Attempting overflow write (Expected Timeout)", clk, axistream_if_s, config => v_axistream_bfm_config);
    v_axistream_bfm_config.max_wait_cycles_severity := ERROR;
    axistream_if_s.tvalid <= '0'; -- go back to idle state

    -- Empty it to clean up
    for i in 1 to C_DEPTH loop
      axistream_expect(std_logic_vector(to_unsigned(i, C_WIDTH)), "Cleaning up after overflow", clk, axistream_if_m);
    end loop;

    log("Test 6: Underflow condition");
    p_reset(arst_b);
    wait for 200 ns;

    -- Attempt to read from empty FIFO (should be blocked by tvalid)
    wait until rising_edge(clk);
    check_value(m_axis_tvalid, '0', ERROR, "Checking FIFO is empty before underflow test");

    v_axistream_bfm_config.max_wait_cycles_severity := WARNING;
    increment_expected_alerts(WARNING, 1); -- Expect timeout
    axistream_receive(v_data_array, v_len, v_user, v_strb, v_id, v_dest, "Attempting underflow read (Expected Timeout)", clk, axistream_if_m, config => v_axistream_bfm_config);
    v_axistream_bfm_config.max_wait_cycles_severity := ERROR;

    -- Tests 7 and 8 drive the handshakes directly (cycle accurate)
    -- Positive acknowledges are not logged (several checks per cycle)
    disable_log_msg(ID_POS_ACK);

    log(ID_LOG_HDR, "Test 7: Simultaneous push and pop at every fill level (0 to " & to_string(C_DEPTH) & ")");
    for level in 0 to C_DEPTH loop
      p_reset(arst_b);
      model_reset;
      wait for 200 ns;

      -- Fill up to the level
      for i in 1 to level loop
        cycle(true, false, "T7 level " & to_string(level) & " fill");
      end loop;

      -- One isolated simultaneous push + pop (at full: only the pop is accepted)
      cycle(true , true , "T7 level " & to_string(level) & " push+pop");
      cycle(false, false, "T7 level " & to_string(level) & " idle");

      -- Back-to-back simultaneous push + pop
      for i in 1 to 4 loop
        cycle(true, true, "T7 level " & to_string(level) & " push+pop burst " & to_string(i));
      end loop;

      -- Drain and check the order of the remaining words
      while v_model_wr /= v_model_rd loop
        cycle(false, true, "T7 level " & to_string(level) & " drain");
      end loop;
      cycle(false, false, "T7 level " & to_string(level) & " empty");
      cycle_idle;
    end loop;

    log(ID_LOG_HDR, "Test 8: Random push and pop");
    p_reset(arst_b);
    model_reset;
    wait for 200 ns;
    for phase in 0 to 3 loop
      case phase is
        when 0      => v_push_prob := 50; v_pop_prob := 50;
        when 1      => v_push_prob := 80; v_pop_prob := 30; -- tends to full
        when 2      => v_push_prob := 30; v_pop_prob := 80; -- tends to empty
        when others => v_push_prob := 70; v_pop_prob := 70;
      end case;
      for i in 1 to 300 loop
        v_push := random(1, 100) <= v_push_prob;
        v_pop  := random(1, 100) <= v_pop_prob;
        cycle(v_push, v_pop, "T8 phase " & to_string(phase) & " cycle " & to_string(i));
      end loop;
    end loop;
    while v_model_wr /= v_model_rd loop
      cycle(false, true, "T8 drain");
    end loop;
    cycle(false, false, "T8 empty");
    cycle_idle;
    log(ID_SEQUENCER, "Test 8: " & to_string(v_model_wr) & " words transferred");
    log(ID_SEQUENCER, "Tests 7 and 8: " & to_string(v_nb_checks) & " cycle checks (flags and data)");
    enable_log_msg(ID_POS_ACK);

    wait for 200 ns;
    report_alert_counters(FINAL);
    log(ID_LOG_HDR, "Simulation finished successfully (SYNC_READ=" & to_string(SYNC_READ) & ")");
    std.env.stop;
    wait;
  end process;
end architecture;

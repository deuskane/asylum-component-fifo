library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


library asylum;
use     asylum.fifo_pkg.all;

library uvvm_util;
context uvvm_util.uvvm_util_context;

library bitvis_vip_axistream;
use bitvis_vip_axistream.axistream_bfm_pkg.all;

entity fifo_sync_tb is
  generic (
    SYNC_READ : boolean := false -- true: synchronous read, false: asynchronous read
  );
end entity;

architecture func of fifo_sync_tb is
  constant C_WIDTH      : natural := 8;
  constant C_DEPTH      : natural := 16;
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
      s_axis_nb_elt_empty_o => open,
      s_axis_full_o         => open,
      s_axis_empty_o        => open,
      m_axis_tvalid_o       => m_axis_tvalid,
      m_axis_tready_i       => m_axis_tready,
      m_axis_tdata_o        => m_axis_tdata,
      m_axis_nb_elt_full_o  => open,
      m_axis_full_o         => open,
      m_axis_empty_o        => open
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
  begin
    log(ID_LOG_HDR, "Starting FIFO simulation: SYNC_READ = " & to_string(SYNC_READ));
    

    log(ID_LOG_HDR, "Test 1: Simple write/read sequence");
    p_reset(arst_b);
    wait for 200 ns;

    for i in 1 to 5 loop
      v_data := std_logic_vector(to_unsigned(i, C_WIDTH));
      axistream_transmit(v_data, "Sending data " & to_string(i), clk, axistream_if_s);
    end loop;

    for i in 1 to 5 loop
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
    axistream_if_s.tvalid <= '0';

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

    wait for 200 ns;
    report_alert_counters(FINAL);
    log(ID_LOG_HDR, "Simulation finished successfully (SYNC_READ=" & to_string(SYNC_READ) & ")");
    std.env.stop;
    wait;
  end process;
end architecture;

-------------------------------------------------------------------------------
-- Title      : fifo_sync
-- Project    : PicoSOC
-------------------------------------------------------------------------------
-- File       : fifo_sync.vhd
-- Author     : Mathieu Rosiere
-- Company    : 
-- Created    : 2025-07-05
-- Last update: 2025-11-08
-- Platform   : 
-- Standard   : VHDL'87
-------------------------------------------------------------------------------
-- Description:
-------------------------------------------------------------------------------
-- Copyright (c) 2017
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2025-07-05  0.1      mrosiere Created
-- 2026-06-10  0.2      mrosiere Add SYNC_READ generic
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library asylum;
use     asylum.math_pkg.all;
use     asylum.ram_pkg.all;

entity fifo_sync is
  -- =====[ Interfaces ]==========================
  generic (
    WIDTH                  : natural := 8;
    DEPTH                  : natural := 4;
    SYNC_READ              : boolean := false
    );                     
  port (                   
    clk_i                  : in  std_logic;
    arst_b_i               : in  std_logic;
                           
    s_axis_tvalid_i        : in  std_logic;
    s_axis_tready_o        : out std_logic;
    s_axis_tdata_i         : in  std_logic_vector(WIDTH-1      downto 0);
    s_axis_nb_elt_empty_o  : out std_logic_vector(clog2(DEPTH) downto 0);
    s_axis_full_o          : out std_logic;
    s_axis_empty_o         : out std_logic;
                           
    m_axis_tvalid_o        : out std_logic;
    m_axis_tready_i        : in  std_logic;
    m_axis_tdata_o         : out std_logic_vector(WIDTH-1      downto 0);
    m_axis_nb_elt_full_o   : out std_logic_vector(clog2(DEPTH) downto 0);
    m_axis_full_o          : out std_logic;
    m_axis_empty_o         : out std_logic

    );
end fifo_sync;

architecture rtl of fifo_sync is
  constant ADDR         : natural := clog2(DEPTH);
  -- =====[ Signals ]=============================
  signal rptr_next       : unsigned(ADDR downto 0);
  signal rptr            : unsigned(ADDR downto 0);
  signal wptr_next       : unsigned(ADDR downto 0);
  signal wptr            : unsigned(ADDR downto 0);
  signal ptr_msb_ne      : std_ulogic;
  signal ptr_msb_eq      : std_ulogic;
  signal ptr_lsb_eq      : std_ulogic;
  signal full            : std_ulogic;
  signal empty           : std_ulogic;
  signal nb_elt_full     : unsigned(ADDR downto 0);
  signal nb_elt_empty    : unsigned(ADDR downto 0);

  signal m_axis_tvalid   : std_ulogic;
  signal s_axis_tready   : std_ulogic;
  signal m_axis_transfer : std_ulogic;
  signal s_axis_transfer : std_ulogic;

  -- RAM read interface (used in SYNC_READ mode)
  signal ram_re          : std_ulogic;
  signal ram_raddr       : std_logic_vector(ADDR -1 downto 0);
  signal ram_rdata       : std_logic_vector(WIDTH-1 downto 0);

  signal ram_we          : std_ulogic;
  signal ram_waddr       : std_logic_vector(ADDR -1 downto 0);
  signal ram_wdata       : std_logic_vector(WIDTH-1 downto 0);

  -- Output register (SYNC_READ mode)
  signal m_axis_tdata_r  : std_logic_vector(WIDTH-1 downto 0);
  signal m_axis_tvalid_r : std_ulogic;
  
begin  -- rtl
  
  -----------------------------------------------------------------------------
  -- FIFO Flag
  -----------------------------------------------------------------------------
  ptr_msb_ne   <= wptr(ADDR) xor rptr(ADDR);
  ptr_msb_eq   <= not ptr_msb_ne;
  ptr_lsb_eq   <= '1' when wptr(ADDR-1 downto 0)  = rptr(ADDR-1 downto 0)  else '0';
               
  empty        <= ptr_lsb_eq and ptr_msb_eq;
  full         <= ptr_lsb_eq and ptr_msb_ne;
               
  nb_elt_full  <= ((ptr_msb_ne&wptr(ADDR-1 downto 0))-
                   ("0"&       rptr(ADDR-1 downto 0)));

  nb_elt_empty <= ((ptr_msb_eq&rptr(ADDR-1 downto 0))-
                   ("0"&       wptr(ADDR-1 downto 0)));

  -----------------------------------------------------------------------------
  -- Pointer update
  -----------------------------------------------------------------------------
  -- In ASYNC_READ mode  : rptr advances on the master handshake.
  -- In SYNC_READ  mode  : rptr advances when a word is loaded from the RAM
  --                       into the output register (ram_re), one cycle ahead.

  rptr_next <= rptr + 1;
  wptr_next <= wptr + 1;

  process (clk_i, arst_b_i) is
  begin  -- process
    if arst_b_i = '0'
    then
      rptr <= (others => '0');
      wptr <= (others => '0');
      
    elsif rising_edge(clk_i)
    then
      if (m_axis_transfer = '1')
      then
        rptr <= rptr_next;
      end if;

      if (s_axis_transfer = '1')
      then
        wptr <= wptr_next;
      end if;
      
    end if;
  end process;
  
  -----------------------------------------------------------------------------
  -- Internal RAM
  -----------------------------------------------------------------------------
  ins_RAM : ram_1r1w
    generic map (
      WIDTH     => WIDTH
     ,DEPTH     => DEPTH
     ,SYNC_READ => SYNC_READ
      )
    port map(
      clk_i   => clk_i
     ,cke_i   => '1'
     ,re_i    => ram_re
     ,raddr_i => ram_raddr
     ,rdata_o => ram_rdata
     ,we_i    => ram_we
     ,waddr_i => ram_waddr
     ,wdata_i => ram_wdata
     );

  ram_wdata <= s_axis_tdata_i;
  -----------------------------------------------------------------------------
  -- AXI-Stream Command : Write side (common)
  -----------------------------------------------------------------------------
  s_axis_tready          <= not full;
  s_axis_transfer        <= s_axis_tvalid_i and s_axis_tready;

  s_axis_tready_o        <= s_axis_tready;
  s_axis_nb_elt_empty_o  <= std_logic_vector(nb_elt_empty);
  s_axis_full_o          <= full ;
  s_axis_empty_o         <= empty;

  ram_waddr              <= std_logic_vector(wptr(ADDR-1 downto 0));
  ram_we                 <= s_axis_transfer;
  -----------------------------------------------------------------------------
  -- AXI-Stream Command : Read side             
  -----------------------------------------------------------------------------
  m_axis_tvalid        <= not empty;
  m_axis_transfer      <= m_axis_tvalid and m_axis_tready_i;

  gen_async_read: if not SYNC_READ
  generate
    -- Combinational RAM read : data available the same cycle as raddr.
    ram_re               <= m_axis_tready_i;
    ram_raddr            <= std_logic_vector(rptr(ADDR-1 downto 0));

    m_axis_tdata_o       <= ram_rdata;
  end generate gen_async_read;

  gen_sync_read: if SYNC_READ
  generate
    ram_re               <= m_axis_tready_i;
    ram_raddr            <= std_logic_vector(rptr_next(ADDR-1 downto 0));  

    process (clk_i, arst_b_i) is
    begin
      if arst_b_i = '0'
      then
        m_axis_tvalid_r <= '0';
        m_axis_tdata_r  <= (others => '0');
      elsif rising_edge(clk_i)
      then

        -- Clear valid when data is accepted by master
        if (m_axis_tvalid_r = '1' and m_axis_tready_i = '1')
        then
          m_axis_tvalid_r <= '0';  
        end if;

        -- Load output register when RAM data is valid (one cycle after ram_re)
        if (ram_we = '1' and empty = '1')
        then
          m_axis_tvalid_r <= '1';
          m_axis_tdata_r  <= ram_wdata;
        end if;
        
      end if;
    end process;

    m_axis_tdata_o <= m_axis_tdata_r when m_axis_tvalid_r = '1' else
                      ram_rdata; -- In case of back-to-back reads, bypass the output register.
  end generate gen_sync_read;

  m_axis_tvalid_o        <= m_axis_tvalid;
  m_axis_nb_elt_full_o   <= std_logic_vector(nb_elt_full);
  m_axis_full_o          <= full ;
  m_axis_empty_o         <= empty;
  
-- synthesis translate_off
  process (clk_i) is
  begin  -- process
    if rising_edge(clk_i)
    then
      assert (nb_elt_full+nb_elt_empty) = DEPTH report "nb_elt_full + nb_elt_empty must be always equal DEPTH" severity error;
    end if;
  end process;
  
-- synthesis translate_on

end rtl;

-------------------------------------------------------------------------------
-- Title      : fifo_sync
-- Project    : PicoSOC
-------------------------------------------------------------------------------
-- File       : fifo_sync.vhd
-- Author     : Mathieu Rosiere
-- Company    : 
-- Created    : 2025-07-05
-- Last update: 2025-07-09
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
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use     work.math_pkg.all;
use     work.ram_1r1w_pkg.all;

entity fifo_sync is
  -- =====[ Interfaces ]==========================
  generic (
    WIDTH                  : natural := 8;
    DEPTH                  : natural := 4
    );                     
  port (                   
    clk_i                  : in  std_logic;
    arst_b_i               : in  std_logic;
                           
    s_axis_tvalid_i        : in  std_logic;
    s_axis_tready_o        : out std_logic;
    s_axis_tdata_i         : in  std_logic_vector(WIDTH-1 downto 0);
    s_axis_nb_elt_empty_o  : out std_logic_vector(clog2(DEPTH) downto 0);
                           
    m_axis_tvalid_o        : out std_logic;
    m_axis_tready_i        : in  std_logic;
    m_axis_tdata_o         : out std_logic_vector(WIDTH-1 downto 0);

    m_axis_nb_elt_full_o   : out std_logic_vector(clog2(DEPTH) downto 0)

    );
end fifo_sync;

architecture rtl of fifo_sync is
  -- =====[ Signals ]=============================
  signal rptr          : unsigned(clog2(DEPTH) downto 0);
  signal wptr          : unsigned(clog2(DEPTH) downto 0);
  signal ptr_msb_ne    : std_ulogic;
  signal ptr_msb_eq    : std_ulogic;
  signal ptr_lsb_eq    : std_ulogic;
  signal full          : std_ulogic;
  signal empty         : std_ulogic;
  signal nb_elt_full   : unsigned(clog2(DEPTH) downto 0);
  signal nb_elt_empty  : unsigned(clog2(DEPTH) downto 0);

  signal m_axis_tvalid   : std_ulogic;
  signal s_axis_tready   : std_ulogic;
  signal m_axis_transfer : std_ulogic;
  signal s_axis_transfer : std_ulogic;
  
begin  -- rtl
  
  -----------------------------------------------------------------------------
  -- FIFO Flag
  -----------------------------------------------------------------------------
  ptr_msb_ne   <= wptr(clog2(DEPTH)) xor rptr(clog2(DEPTH));
  ptr_msb_eq   <= not ptr_msb_ne;
  ptr_lsb_eq   <= '1' when wptr(clog2(DEPTH)-1 downto 0)  = rptr(clog2(DEPTH)-1 downto 0)  else '0';
               
  empty        <= ptr_lsb_eq and ptr_msb_eq;
  full         <= ptr_lsb_eq and ptr_msb_ne;
               
  nb_elt_full  <= ((ptr_msb_ne&wptr(clog2(DEPTH)-1 downto 0))-
                   ("0"&       rptr(clog2(DEPTH)-1 downto 0)));

  nb_elt_empty <= ((ptr_msb_eq&rptr(clog2(DEPTH)-1 downto 0))-
                   ("0"&       wptr(clog2(DEPTH)-1 downto 0)));

  -----------------------------------------------------------------------------
  -- Pointer update
  -----------------------------------------------------------------------------
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
        rptr <= rptr+1;
      end if;

      if (s_axis_transfer = '1')
      then
        wptr <= wptr+1;
      end if;
      
    end if;
  end process;
  
  -----------------------------------------------------------------------------
  -- Internal RAM
  -----------------------------------------------------------------------------
  ins_RAM : ram_1r1w
    generic map (
      WIDTH => WIDTH
     ,DEPTH => DEPTH
      )
    port map(
      clk_i   => clk_i
     ,cke_i   => '1'
     ,re_i    => m_axis_tvalid
     ,raddr_i => std_logic_vector(rptr(clog2(DEPTH)-1 downto 0))
     ,rdata_o => m_axis_tdata_o
     ,we_i    => s_axis_transfer
     ,waddr_i => std_logic_vector(wptr(clog2(DEPTH)-1 downto 0))
     ,wdata_i => s_axis_tdata_i
     );
  
  -----------------------------------------------------------------------------
  -- AXI-Stream Command
  -----------------------------------------------------------------------------
  m_axis_transfer        <= m_axis_tvalid   and m_axis_tready_i;
  s_axis_transfer        <= s_axis_tvalid_i and s_axis_tready;

  m_axis_tvalid          <= not empty;
  m_axis_tvalid_o        <= m_axis_tvalid;
  m_axis_nb_elt_full_o   <= std_logic_vector(nb_elt_full);

  s_axis_tready          <= not full;
  s_axis_tready_o        <= s_axis_tready;
  s_axis_nb_elt_empty_o  <= std_logic_vector(nb_elt_empty);

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

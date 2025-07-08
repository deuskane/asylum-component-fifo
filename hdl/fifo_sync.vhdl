-------------------------------------------------------------------------------
-- Title      : fifo_sync
-- Project    : PicoSOC
-------------------------------------------------------------------------------
-- File       : fifo_sync.vhd
-- Author     : Mathieu Rosiere
-- Company    : 
-- Created    : 2025-07-05
-- Last update: 2025-07-08
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
use work.math_pkg.all;
use work.ram_1r1w_pkg.all;

entity fifo_sync is
  -- =====[ Interfaces ]==========================
  generic (
    WIDTH           : natural := 32;
    DEPTH           : natural := 32
    );
  port (
    clk_i           : in  std_logic;
    arst_b_i        : in  std_logic;

    s_axis_tvalid_i : in  std_logic;
    s_axis_tready_o : out std_logic;
    s_axis_tdata_i  : in  std_logic_vector(WIDTH-1 downto 0);
    s_axis_nb_elt_o : out std_logic_vector(clog2(DEPTH) downto 0);
    
    m_axis_tvalid_o : out std_logic;
    m_axis_tready_i : in  std_logic;
    m_axis_tdata_o  : out std_logic_vector(WIDTH-1 downto 0);

    m_axis_nb_elt_o : out std_logic_vector(clog2(DEPTH) downto 0);

    );
end fifo_sync;

architecture rtl of fifo_sync is
  -- =====[ Types ]===============================
  type ram_t is array (DEPTH-1 downto 0) of std_logic_vector(WIDTH -1 downto 0);

  -- =====[ Registers ]===========================
  signal ram_r  : ram_t;
  
  -- =====[ Signals ]=============================
  signal rptr          : unsigned(clog2(DEPTH) downto 0);
  signal wptr          : unsigned(clog2(DEPTH) downto 0);
  signal ptr_msb_ne    : std_ulogic;
  signal ptr_msb_eq    : std_ulogic;
  signal ptr_lsb_eq    : std_ulogic;
  signal full          : std_ulogic;
  signal empty         : std_ulogic;
  signal nb_elt        : unsigned(clog2(DEPTH) downto 0);

  signal m_axis_tvalid : std_ulogic;
  
begin  -- rtl
  
  -----------------------------------------------------------------------------
  -- FIFO Flag
  -----------------------------------------------------------------------------
  ptr_msb_ne <= wptr(clog2(DEPTH)) xor rptr(clog2(DEPTH));
  ptr_msb_eq <= not ptr_msb_ne;
  ptr_lsb_eq <= '1' when wptr(clog2(DEPTH)-1 downto 0)  = rptr(clog2(DEPTH)-1 downto 0)  else '0';
  
  empty      <= ptr_lsb_eq and ptr_msb_eq;
  full       <= ptr_lsb_eq and ptr_msb_ne;

  nb_elt     <= ((ptr_msb_ne&wptr(clog2(DEPTH)-1 downto 0))-
                 ("0"&       rptr(clog2(DEPTH)-1 downto 0)));

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
     ,raddr_i => rpt
     ,rdata_o => m_axis_tdata_o
     ,we_i    => s_axis_tvalid_i
     ,waddr_i => wptr
     ,wdata_i => s_axis_tdata_i
     );
  
  -----------------------------------------------------------------------------
  -- AXI-Stream Command
  -----------------------------------------------------------------------------
  m_axis_tvalid   <= not empty;
  s_axis_tready_o <= not full;
end rtl;

-------------------------------------------------------------------------------
-- Title      : fifo_pkg
-- Project    : PicoSOC
-------------------------------------------------------------------------------
-- File       : fifo_pkg.vhd
-- Author     : Mathieu Rosiere
-- Company    : 
-- Created    : 2025-07-05
-- Last update: 2025-07-28
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

package fifo_pkg is

component fifo_sync is
  -- =====[ Parameters ]==========================
  generic (
    WIDTH                  : natural := 8;
    DEPTH                  : natural := 4
    );                     
  -- =====[ Interfaces ]==========================
  port (                   
    clk_i                  : in  std_logic;
    arst_b_i               : in  std_logic;
                           
    s_axis_tvalid_i        : in  std_logic;
    s_axis_tready_o        : out std_logic;
    s_axis_tdata_i         : in  std_logic_vector(WIDTH-1 downto 0);
    s_axis_nb_elt_empty_o  : out std_logic_vector(clog2(DEPTH) downto 0); 
    s_axis_full_o          : out std_logic;
    s_axis_empty_o         : out std_logic;
                          
    m_axis_tvalid_o        : out std_logic;
    m_axis_tready_i        : in  std_logic;
    m_axis_tdata_o         : out std_logic_vector(WIDTH-1 downto 0);
    m_axis_nb_elt_full_o   : out std_logic_vector(clog2(DEPTH) downto 0);
    m_axis_full_o          : out std_logic;
    m_axis_empty_o         : out std_logic

    );
end component;
  
end package fifo_pkg;

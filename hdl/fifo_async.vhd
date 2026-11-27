-------------------------------------------------------------------------------
-- Title      : fifo_async
-- Project    : Asylum
-------------------------------------------------------------------------------
-- File       : fifo_async.vhd
-- Author     : mrosiere
-- Company    :
-- Created    : 2026-11-26
-- Last update: 2026-11-26
-- Platform   :
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description: Dual-clock FIFO : AXI-Stream write side on s_clk_i, AXI-Stream
--              read side on m_clk_i, unrelated clocks (same ports as
--              fifo_sync, one clock per side).
--              * Storage : ram_1r1w_2c, written on s_clk_i, read on m_clk_i
--                (registered read, the next word is read one cycle ahead :
--                m_axis_tdata_o is the head word as soon as m_axis_tvalid_o
--                = 1, first-word fall-through). While the FIFO is empty the
--                read port reads the word that may be being written
--                (collision) : the result is discarded (m_axis_tvalid_o = 0)
--                and read again once the write is seen ; the RAM must keep
--                the word written on a collision.
--              * Pointers of ADDR+1 bits (ADDR = log2(DEPTH)), the MSB
--                tells a full FIFO from an empty one. Each side sends its
--                pointer to the other one in Gray code (one bit changes per
--                word), from a register, through a 2 flip-flop synchronizer
--                (sync2dffrn) per bit : the other side sees an old or the
--                new value, never a mix. The Gray register is updated on
--                the edge of the transfer : no other edge of this clock is
--                needed (it may stop after a transfer, as TCK).
--              * Each side computes its flags with its own pointer and the
--                synchronized pointer of the other side : late by 1 to 2
--                cycles of its clock, never wrong (a word is seen on the read
--                side after it is written, a free place is seen on the write
--                side after it is read).
--                - write side : s_axis_full_o exact (s_axis_tready_o =
--                  not full, 0 during the reset), s_axis_empty_o and s_axis_nb_elt_empty_o
--                  (free places) pessimistic
--                - read side : m_axis_empty_o exact (m_axis_tvalid_o = not
--                  empty), m_axis_full_o and m_axis_nb_elt_full_o (stored
--                  words) pessimistic
--              * arst_b_i resets both sides : asserted asynchronously, released
--                on each side on the second edge of its clock (sync2dffrn,
--                d_i = 1), so it may be released at any time. During the
--                reset of the write side s_axis_tready_o = 0. A side whose
--                clock is stopped (TCK) stays in reset until its clock runs.
--              DEPTH is a power of 2 (1 allowed).
-------------------------------------------------------------------------------
-- Copyright (c) 2026
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author   Description
-- 2026-11-26  1.0      mrosiere Created
-- 2026-11-27  1.1      mrosiere Gray functions of gray_pkg, reset released
--                               on each clock (sync2dffrn), storage
--                               ram_1r1w_2c
-------------------------------------------------------------------------------

library ieee;
use     ieee.std_logic_1164.all;
use     ieee.numeric_std.all;

library asylum;
use     asylum.math_pkg.all;
use     asylum.gray_pkg.all;
use     asylum.ram_pkg.all;
use     asylum.techmap_pkg.all;

entity fifo_async is
  generic (
    WIDTH                  : natural := 8                          -- Word width
   ;DEPTH                  : natural := 4                          -- Number of words (power of 2)
  );
  port (
    -- Reset of both sides (asynchronous, active low)
    arst_b_i               : in  std_logic
    -- Write side (s_clk_i)
   ;s_clk_i                : in  std_logic
   ;s_axis_tvalid_i        : in  std_logic
   ;s_axis_tready_o        : out std_logic
   ;s_axis_tdata_i         : in  std_logic_vector(WIDTH-1      downto 0)
   ;s_axis_nb_elt_empty_o  : out std_logic_vector(clog2(DEPTH) downto 0) -- Free places (pessimistic)
   ;s_axis_full_o          : out std_logic
   ;s_axis_empty_o         : out std_logic                               -- Pessimistic
    -- Read side (m_clk_i)
   ;m_clk_i                : in  std_logic
   ;m_axis_tvalid_o        : out std_logic
   ;m_axis_tready_i        : in  std_logic
   ;m_axis_tdata_o         : out std_logic_vector(WIDTH-1      downto 0)
   ;m_axis_nb_elt_full_o   : out std_logic_vector(clog2(DEPTH) downto 0) -- Stored words (pessimistic)
   ;m_axis_full_o          : out std_logic                               -- Pessimistic
   ;m_axis_empty_o         : out std_logic
  );
end entity fifo_async;

architecture rtl of fifo_async is

  constant ADDR            : natural := clog2(DEPTH);

  subtype  ptr_t is unsigned(ADDR downto 0);

  -- Full : same address, other lap (MSB) ; empty : same pointer. The
  -- addresses are compared as std_logic_vector : equal when DEPTH = 1 (null
  -- vectors ; "=" of numeric_std returns false on a null argument)
  function is_full(w, r : ptr_t) return std_logic is
  begin
    if w(ADDR) /= r(ADDR) and std_logic_vector(w(ADDR-1 downto 0)) = std_logic_vector(r(ADDR-1 downto 0))
    then
      return '1';
    end if;
    return '0';
  end function is_full;

  function is_empty(w, r : ptr_t) return std_logic is
  begin
    if w = r
    then
      return '1';
    end if;
    return '0';
  end function is_empty;

  -- Write side (s_clk_i)
  signal   s_rst_b         : std_logic;                             -- arst_b_i released on s_clk_i
  signal   s_tready        : std_logic;
  signal   wptr_r          : ptr_t;
  signal   wptr_next       : ptr_t;
  signal   wgray_r         : std_logic_vector(ADDR downto 0);
  signal   rgray_s         : std_logic_vector(ADDR downto 0);       -- rgray_r synchronized on s_clk_i
  signal   rptr_s          : ptr_t;
  signal   s_full          : std_logic;
  signal   s_transfer      : std_logic;

  -- Read side (m_clk_i)
  signal   m_rst_b         : std_logic;                             -- arst_b_i released on m_clk_i
  signal   rptr_r          : ptr_t;
  signal   rptr_next       : ptr_t;
  signal   rgray_r         : std_logic_vector(ADDR downto 0);
  signal   wgray_m         : std_logic_vector(ADDR downto 0);       -- wgray_r synchronized on m_clk_i
  signal   wptr_m          : ptr_t;
  signal   m_empty         : std_logic;
  signal   m_transfer      : std_logic;

begin  -- architecture rtl

  -----------------------------------------------------------------------------
  -- Reset of each side : asserted with arst_b_i (asynchronous), released on
  -- the second edge of the clock of the side (sync2dffrn with d_i = 1)
  -----------------------------------------------------------------------------
  ins_s_rst_sync : sync2dffrn
    port map
    (clk_i                 => s_clk_i
    ,arst_b_i              => arst_b_i
    ,d_i                   => '1'
    ,q_o                   => s_rst_b
    );

  ins_m_rst_sync : sync2dffrn
    port map
    (clk_i                 => m_clk_i
    ,arst_b_i              => arst_b_i
    ,d_i                   => '1'
    ,q_o                   => m_rst_b
    );

  -----------------------------------------------------------------------------
  -- Storage : written on s_clk_i, the word at the read pointer of the next
  -- cycle read on every edge of m_clk_i
  -----------------------------------------------------------------------------
  ins_ram : ram_1r1w_2c
    generic map
    (WIDTH                 => WIDTH
    ,DEPTH                 => DEPTH
    )
    port map
    (clk0_i                => s_clk_i
    ,cke0_i                => '1'
    ,we0_i                 => s_transfer
    ,waddr0_i              => std_logic_vector(wptr_r(ADDR-1 downto 0))
    ,wdata0_i              => s_axis_tdata_i
    ,clk1_i                => m_clk_i
    ,cke1_i                => '1'
    ,re1_i                 => '1'
    ,raddr1_i              => std_logic_vector(rptr_next(ADDR-1 downto 0))
    ,rdata1_o              => m_axis_tdata_o
    );

  -----------------------------------------------------------------------------
  -- Write side
  -----------------------------------------------------------------------------
  s_full     <= is_full(wptr_r, rptr_s);
  s_tready   <= s_rst_b and not s_full;                             -- No write during the reset
  s_transfer <= s_axis_tvalid_i and s_tready;
  wptr_next  <= wptr_r + 1 when s_transfer = '1' else
                wptr_r;

  -- Pointer and its Gray code, both registers (no glitch to the
  -- synchronizers), updated on the edge that writes the word : the other
  -- side sees the word with no extra edge of s_clk_i (s_clk_i may stop
  -- after the write, e.g. TCK)
  process(s_clk_i, s_rst_b)
  begin
    if s_rst_b = '0'
    then
      wptr_r  <= (others => '0');
      wgray_r <= (others => '0');
    elsif rising_edge(s_clk_i)
    then
      wptr_r  <= wptr_next;
      wgray_r <= bin2gray(std_logic_vector(wptr_next));
    end if;
  end process;

  gen_rgray_sync: for i in 0 to ADDR
  generate
    ins_rgray_sync : sync2dffrn
      port map
      (clk_i               => s_clk_i
      ,arst_b_i            => s_rst_b
      ,d_i                 => rgray_r(i)
      ,q_o                 => rgray_s(i)
      );
  end generate gen_rgray_sync;

  rptr_s <= unsigned(gray2bin(rgray_s));

  -----------------------------------------------------------------------------
  -- Read side
  -----------------------------------------------------------------------------
  m_empty    <= is_empty(wptr_m, rptr_r);
  m_transfer <= m_axis_tready_i and not m_empty;
  rptr_next  <= rptr_r + 1 when m_transfer = '1' else
                rptr_r;

  process(m_clk_i, m_rst_b)
  begin
    if m_rst_b = '0'
    then
      rptr_r  <= (others => '0');
      rgray_r <= (others => '0');
    elsif rising_edge(m_clk_i)
    then
      rptr_r  <= rptr_next;
      rgray_r <= bin2gray(std_logic_vector(rptr_next));
    end if;
  end process;

  gen_wgray_sync: for i in 0 to ADDR
  generate
    ins_wgray_sync : sync2dffrn
      port map
      (clk_i               => m_clk_i
      ,arst_b_i            => m_rst_b
      ,d_i                 => wgray_r(i)
      ,q_o                 => wgray_m(i)
      );
  end generate gen_wgray_sync;

  wptr_m <= unsigned(gray2bin(wgray_m));

  -----------------------------------------------------------------------------
  -- Outputs
  -----------------------------------------------------------------------------
  s_axis_tready_o        <= s_tready;
  s_axis_full_o          <= s_full;
  s_axis_empty_o         <= is_empty(wptr_r, rptr_s);
  s_axis_nb_elt_empty_o  <= std_logic_vector(to_unsigned(DEPTH, ADDR+1) - (wptr_r - rptr_s));

  m_axis_tvalid_o        <= not m_empty;
  m_axis_full_o          <= is_full(wptr_m, rptr_r);
  m_axis_empty_o         <= m_empty;
  m_axis_nb_elt_full_o   <= std_logic_vector(wptr_m - rptr_r);

-- synthesis translate_off
  assert 2**ADDR = DEPTH
    report "fifo_async : DEPTH (" & integer'image(DEPTH) & ") is not a power of 2"
    severity failure;
-- synthesis translate_on

end architecture rtl;

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
--              * Storage : ram_2rw_2c, port 0 written on s_clk_i, port 1
--                read on m_clk_i (registered read, the next word is read
--                one cycle ahead : m_axis_tdata_o is the head word as soon
--                as m_axis_tvalid_o = 1, first-word fall-through).
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
--                  not full), s_axis_empty_o and s_axis_nb_elt_empty_o
--                  (free places) pessimistic
--                - read side : m_axis_empty_o exact (m_axis_tvalid_o = not
--                  empty), m_axis_full_o and m_axis_nb_elt_full_o (stored
--                  words) pessimistic
--              * arst_b_i resets both sides : assert it asynchronously,
--                release it when each clock is stopped or synchronously to
--                it (reset synchronizer of the user), with both sides idle.
--              DEPTH is a power of 2 (1 allowed).
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

library asylum;
use     asylum.math_pkg.all;
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

  -- Gray code of a pointer, and back
  function bin2gray(b : ptr_t) return std_logic_vector is
  begin
    return std_logic_vector(b xor shift_right(b, 1));
  end function bin2gray;

  function gray2bin(g : std_logic_vector(ADDR downto 0)) return ptr_t is
    variable b : ptr_t;
  begin
    b(ADDR) := g(ADDR);
    for i in ADDR-1 downto 0
    loop
      b(i)  := b(i+1) xor g(i);
    end loop;
    return b;
  end function gray2bin;

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
  signal   wptr_r          : ptr_t;
  signal   wptr_next       : ptr_t;
  signal   wgray_r         : std_logic_vector(ADDR downto 0);
  signal   rgray_s         : std_logic_vector(ADDR downto 0);       -- rgray_r synchronized on s_clk_i
  signal   rptr_s          : ptr_t;
  signal   s_full          : std_logic;
  signal   s_transfer      : std_logic;

  -- Read side (m_clk_i)
  signal   rptr_r          : ptr_t;
  signal   rptr_next       : ptr_t;
  signal   rgray_r         : std_logic_vector(ADDR downto 0);
  signal   wgray_m         : std_logic_vector(ADDR downto 0);       -- wgray_r synchronized on m_clk_i
  signal   wptr_m          : ptr_t;
  signal   m_empty         : std_logic;
  signal   m_transfer      : std_logic;

begin  -- architecture rtl

  -----------------------------------------------------------------------------
  -- Storage : port 0 writes (s_clk_i), port 1 reads (m_clk_i) the word at
  -- the read pointer of the next cycle
  -----------------------------------------------------------------------------
  ins_ram : ram_2rw_2c
    generic map
    (WIDTH                 => WIDTH
    ,DEPTH                 => DEPTH
    )
    port map
    (clk0_i                => s_clk_i
    ,cke0_i                => '1'
    ,cs0_i                 => s_transfer
    ,we0_i                 => '1'
    ,addr0_i               => std_logic_vector(wptr_r(ADDR-1 downto 0))
    ,wdata0_i              => s_axis_tdata_i
    ,rdata0_o              => open
    ,clk1_i                => m_clk_i
    ,cke1_i                => '1'
    ,cs1_i                 => '1'
    ,we1_i                 => '0'
    ,addr1_i               => std_logic_vector(rptr_next(ADDR-1 downto 0))
    ,wdata1_i              => (WIDTH-1 downto 0 => '0')
    ,rdata1_o              => m_axis_tdata_o
    );

  -----------------------------------------------------------------------------
  -- Write side
  -----------------------------------------------------------------------------
  s_full     <= is_full(wptr_r, rptr_s);
  s_transfer <= s_axis_tvalid_i and not s_full;
  wptr_next  <= wptr_r + 1 when s_transfer = '1' else
                wptr_r;

  -- Pointer and its Gray code, both registers (no glitch to the
  -- synchronizers), updated on the edge that writes the word : the other
  -- side sees the word with no extra edge of s_clk_i (s_clk_i may stop
  -- after the write, e.g. TCK)
  process(s_clk_i, arst_b_i)
  begin
    if arst_b_i = '0'
    then
      wptr_r  <= (others => '0');
      wgray_r <= (others => '0');
    elsif rising_edge(s_clk_i)
    then
      wptr_r  <= wptr_next;
      wgray_r <= bin2gray(wptr_next);
    end if;
  end process;

  gen_rgray_sync: for i in 0 to ADDR
  generate
    ins_rgray_sync : sync2dffrn
      port map
      (clk_i               => s_clk_i
      ,arst_b_i            => arst_b_i
      ,d_i                 => rgray_r(i)
      ,q_o                 => rgray_s(i)
      );
  end generate gen_rgray_sync;

  rptr_s <= gray2bin(rgray_s);

  -----------------------------------------------------------------------------
  -- Read side
  -----------------------------------------------------------------------------
  m_empty    <= is_empty(wptr_m, rptr_r);
  m_transfer <= m_axis_tready_i and not m_empty;
  rptr_next  <= rptr_r + 1 when m_transfer = '1' else
                rptr_r;

  process(m_clk_i, arst_b_i)
  begin
    if arst_b_i = '0'
    then
      rptr_r  <= (others => '0');
      rgray_r <= (others => '0');
    elsif rising_edge(m_clk_i)
    then
      rptr_r  <= rptr_next;
      rgray_r <= bin2gray(rptr_next);
    end if;
  end process;

  gen_wgray_sync: for i in 0 to ADDR
  generate
    ins_wgray_sync : sync2dffrn
      port map
      (clk_i               => m_clk_i
      ,arst_b_i            => arst_b_i
      ,d_i                 => wgray_r(i)
      ,q_o                 => wgray_m(i)
      );
  end generate gen_wgray_sync;

  wptr_m <= gray2bin(wgray_m);

  -----------------------------------------------------------------------------
  -- Outputs
  -----------------------------------------------------------------------------
  s_axis_tready_o        <= not s_full;
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

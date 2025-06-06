-- ================================================================================ --
-- NEORV32 SoC - XBUS to AXI4 Bridge                                                --
-- -------------------------------------------------------------------------------- --
-- The NEORV32 RISC-V Processor - https://github.com/stnolting/neorv32              --
-- Copyright (c) NEORV32 contributors.                                              --
-- Copyright (c) 2020 - 2025 Stephan Nolting. All rights reserved.                  --
-- Licensed under the BSD-3-Clause license, see LICENSE for details.                --
-- SPDX-License-Identifier: BSD-3-Clause                                            --
-- ================================================================================ --

library ieee;
use ieee.std_logic_1164.all;

entity xbus2axi4_bridge is
  port (
    -- Global control --
    clk           : in  std_logic;
    resetn        : in  std_logic;
    -- XBUS device interface --
    xbus_adr_i    : in  std_ulogic_vector(31 downto 0);
    xbus_dat_i    : in  std_ulogic_vector(31 downto 0);
    xbus_tag_i    : in  std_ulogic_vector(2 downto 0);
    xbus_we_i     : in  std_ulogic;
    xbus_sel_i    : in  std_ulogic_vector(3 downto 0);
    xbus_stb_i    : in  std_ulogic;
    xbus_ack_o    : out std_ulogic;
    xbus_err_o    : out std_ulogic;
    xbus_dat_o    : out std_ulogic_vector(31 downto 0);
    -- AXI4 host write address channel --
    m_axi_awaddr  : out std_logic_vector(31 downto 0);
    m_axi_awlen   : out std_logic_vector(7 downto 0);
    m_axi_awsize  : out std_logic_vector(2 downto 0);
    m_axi_awburst : out std_logic_vector(1 downto 0);
    m_axi_awcache : out std_logic_vector(3 downto 0);
    m_axi_awprot  : out std_logic_vector(2 downto 0);
    m_axi_awvalid : out std_logic;
    m_axi_awready : in  std_logic;
    -- AXI4 host write data channel --
    m_axi_wdata   : out std_logic_vector(31 downto 0);
    m_axi_wstrb   : out std_logic_vector(3 downto 0);
    m_axi_wlast   : out std_logic;
    m_axi_wvalid  : out std_logic;
    m_axi_wready  : in  std_logic;
    -- AXI4 host read address channel --
    m_axi_araddr  : out std_logic_vector(31 downto 0);
    m_axi_arlen   : out std_logic_vector(7 downto 0);
    m_axi_arsize  : out std_logic_vector(2 downto 0);
    m_axi_arburst : out std_logic_vector(1 downto 0);
    m_axi_arcache : out std_logic_vector(3 downto 0);
    m_axi_arprot  : out std_logic_vector(2 downto 0);
    m_axi_arvalid : out std_logic;
    m_axi_arready : in  std_logic;
    -- AXI4 host read data channel --
    m_axi_rdata   : in  std_logic_vector(31 downto 0);
    m_axi_rresp   : in  std_logic_vector(1 downto 0);
    m_axi_rlast   : in  std_logic;
    m_axi_rvalid  : in  std_logic;
    m_axi_rready  : out std_logic;
    -- AXI4 host write response channel --
    m_axi_bresp   : in  std_logic_vector(1 downto 0);
    m_axi_bvalid  : in  std_logic;
    m_axi_bready  : out std_logic
  );
end entity;

architecture xbus2axi4_bridge_rtl of xbus2axi4_bridge is

  signal arvalid, awvalid, wvalid, rready, bready, xbus_rd_ack, xbus_rd_err, xbus_wr_ack, xbus_wr_err : std_ulogic;

begin

  -- channel handshake arbiter --
  axi_handshake: process(resetn, clk)
  begin
    if (resetn = '0') then
      arvalid <= '0';
      awvalid <= '0';
      wvalid  <= '0';
      rready  <= '0';
      bready  <= '0';
    elsif rising_edge(clk) then
      arvalid <= (xbus_stb_i and (not xbus_we_i)) or (arvalid and std_ulogic(not m_axi_arready));
      awvalid <= (xbus_stb_i and (    xbus_we_i)) or (awvalid and std_ulogic(not m_axi_awready));
      wvalid  <= (xbus_stb_i and (    xbus_we_i)) or (wvalid  and std_ulogic(not m_axi_wready));
      rready  <= (xbus_stb_i and (not xbus_we_i)) or (rready  and std_ulogic(not m_axi_rvalid));
      bready  <= (xbus_stb_i and (    xbus_we_i)) or (bready  and std_ulogic(not m_axi_bvalid));
    end if;
  end process axi_handshake;

  -- read address channel --
  m_axi_araddr  <= std_logic_vector(xbus_adr_i);
  m_axi_arlen   <= (others => '0'); -- burst length = 1 transfer
  m_axi_arsize  <= "010"; -- 4 bytes per transfer
  m_axi_arburst <= "01"; -- incrementing bursts only
  m_axi_arcache <= "0011"; -- recommended by Vivado
  m_axi_arprot  <= std_logic_vector(xbus_tag_i);
  m_axi_arvalid <= std_logic(arvalid);

  -- read data channel --
  m_axi_rready  <= std_logic(rready);
  xbus_rd_ack   <= '1' when (rready = '1') and (m_axi_rvalid = '1') and (m_axi_rresp  = "00") else '0';
  xbus_rd_err   <= '1' when (rready = '1') and (m_axi_rvalid = '1') and (m_axi_rresp /= "00") else '0';
--m_axi_rlast   -- yet unused
  xbus_dat_o    <= std_ulogic_vector(m_axi_rdata);

  -- write address channel --
  m_axi_awaddr  <= std_logic_vector(xbus_adr_i);
  m_axi_awlen   <= (others => '0'); -- burst length = 1 transfer
  m_axi_awsize  <= "010"; -- 4 bytes per transfer
  m_axi_awburst <= "01"; -- incrementing bursts only
  m_axi_awcache <= "0011"; -- recommended by Vivado
  m_axi_awprot  <= std_logic_vector(xbus_tag_i);
  m_axi_awvalid <= std_logic(awvalid);

  -- write data channel --
  m_axi_wdata   <= std_logic_vector(xbus_dat_i);
  m_axi_wstrb   <= std_logic_vector(xbus_sel_i);
  m_axi_wlast   <= std_logic(wvalid); -- there is only one transfer so it is also the last
  m_axi_wvalid  <= std_logic(wvalid);

  -- write response channel --
  m_axi_bready  <= std_logic(bready);
  xbus_wr_ack   <= '1' when (bready = '1') and (m_axi_bvalid = '1') and (m_axi_bresp  = "00") else '0';
  xbus_wr_err   <= '1' when (bready = '1') and (m_axi_bvalid = '1') and (m_axi_bresp /= "00") else '0';

  -- XBUS response --
  xbus_ack_o    <= xbus_rd_ack or xbus_wr_ack;
  xbus_err_o    <= xbus_rd_err or xbus_wr_err;

end architecture;

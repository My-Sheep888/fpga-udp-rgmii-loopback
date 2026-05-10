`timescale 1ns / 1ps

// 正点原子达芬奇 Pro 核心板网口 eth0 上板顶层：
// 负责把板级 sys_clk/sys_rst_n/eth_* 管脚接入通用 RGMII UDP 回环核心。
module davinci_pro_eth0_udp_loopback_top #(
    parameter [47:0] LOCAL_MAC = 48'h00_11_22_33_44_66,
    parameter [31:0] LOCAL_IP  = {8'd192, 8'd168, 8'd6, 8'd12},
    parameter integer MAX_PAYLOAD_BYTES = 1472,
    parameter integer IDELAY_VALUE = 0,
    parameter integer PHY_RESET_DELAY_CYCLES = 1000000
)(
    input             sys_clk,
    input             sys_rst_n,

    input             eth_rxc,
    input             eth_rx_ctl,
    input      [3:0]  eth_rxd,
    output            eth_txc,
    output            eth_tx_ctl,
    output     [3:0]  eth_txd,
    output            eth_rst_n,
    output     [3:0]  led
);

    wire clk_200m;
    wire clk_200m_locked;
    wire phy_ready;
    wire core_rst_n;
    wire packet_seen;
    wire packet_echoed;
    wire packet_dropped;

    reg eth_rx_ctl_meta;
    reg eth_rx_ctl_sync;
    reg rx_activity_seen;
    reg packet_seen_status;
    reg packet_echoed_status;

    // 达芬奇 Pro 系统时钟为 50MHz，这里用 MMCM 原语生成 IDELAYCTRL 需要的 200MHz。
    clk_200m_gen_artix7 u_clk_200m_gen (
        .clk_in(sys_clk),
        .rst_n(sys_rst_n),
        .clk_200m(clk_200m),
        .locked(clk_200m_locked)
    );

    // PHY 复位延时。默认 50MHz 下等待 1,000,000 个周期，约 20ms。
    phy_reset_delay #(
        .RESET_DELAY_CYCLES(PHY_RESET_DELAY_CYCLES)
    ) u_phy_reset_delay (
        .clk(sys_clk),
        .rst_n(sys_rst_n & clk_200m_locked),
        .phy_rst_n(eth_rst_n),
        .ready(phy_ready)
    );

    assign core_rst_n = sys_rst_n & clk_200m_locked & phy_ready;

    // LED 状态指示：
    // LED0：PHY 复位已释放；
    // LED1：FPGA 管脚侧观察到 RGMII 接收活动；
    // LED2：协议核心已接收一个可处理的 ARP/UDP 包；
    // LED3：协议核心已完成一次 ARP/UDP 回包发送。
    always @(posedge sys_clk or negedge sys_rst_n) begin
        if (!sys_rst_n) begin
            eth_rx_ctl_meta <= 1'b0;
            eth_rx_ctl_sync <= 1'b0;
            rx_activity_seen <= 1'b0;
            packet_seen_status <= 1'b0;
            packet_echoed_status <= 1'b0;
        end else begin
            eth_rx_ctl_meta <= eth_rx_ctl;
            eth_rx_ctl_sync <= eth_rx_ctl_meta;
            if (eth_rx_ctl_sync)
                rx_activity_seen <= 1'b1;
            if (packet_seen)
                packet_seen_status <= 1'b1;
            if (packet_echoed)
                packet_echoed_status <= 1'b1;
        end
    end

    assign led[0] = phy_ready;
    assign led[1] = rx_activity_seen;
    assign led[2] = packet_seen_status;
    assign led[3] = packet_echoed_status | packet_dropped;

    // 通用 RGMII UDP 回环顶层，板级 eth_* 信号在这里映射到 rgmii_* 信号。
    udp_loopback_rgmii_artix7_top #(
        .LOCAL_MAC(LOCAL_MAC),
        .LOCAL_IP(LOCAL_IP),
        .MAX_PAYLOAD_BYTES(MAX_PAYLOAD_BYTES),
        .IDELAY_VALUE(IDELAY_VALUE)
    ) u_udp_loopback_rgmii (
        .idelay_clk_200m(clk_200m),
        .rst_n(core_rst_n),
        .rgmii_rxc(eth_rxc),
        .rgmii_rx_ctl(eth_rx_ctl),
        .rgmii_rxd(eth_rxd),
        .rgmii_txc(eth_txc),
        .rgmii_tx_ctl(eth_tx_ctl),
        .rgmii_txd(eth_txd),
        .packet_seen(packet_seen),
        .packet_echoed(packet_echoed),
        .packet_dropped(packet_dropped)
    );

endmodule

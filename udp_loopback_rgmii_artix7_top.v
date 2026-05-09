`timescale 1ns / 1ps

// Artix-7 RGMII 板级顶层：
// 外部接 PHY 的 RGMII 管脚，内部转换成 GMII 后送入 UDP 回环核心。
module udp_loopback_rgmii_artix7_top #(
    parameter [47:0] LOCAL_MAC = 48'h00_11_22_33_44_66,
    parameter [31:0] LOCAL_IP  = {8'd192, 8'd168, 8'd6, 8'd12},
    parameter integer MAX_PAYLOAD_BYTES = 1472,
    parameter integer IDELAY_VALUE = 0
)(
    input             idelay_clk_200m,
    input             rst_n,
    input             rgmii_rxc,
    input             rgmii_rx_ctl,
    input      [3:0]  rgmii_rxd,
    output            rgmii_txc,
    output            rgmii_tx_ctl,
    output     [3:0]  rgmii_txd,
    output            packet_seen,
    output            packet_echoed,
    output            packet_dropped
);

    wire gmii_clk;
    wire gmii_rx_dv;
    wire [7:0] gmii_rxd;
    wire gmii_tx_en;
    wire [7:0] gmii_txd;

    // RGMII 与 GMII 之间的时序/位宽转换。
    // 接收方向使用 IDDR/IDELAY，发送方向使用 ODDR。
    gmii_to_rgmii_artix7 #(
        .IDELAY_VALUE(IDELAY_VALUE)
    ) u_gmii_to_rgmii (
        .idelay_clk_200m(idelay_clk_200m),
        .rgmii_rxc(rgmii_rxc),
        .rgmii_rx_ctl(rgmii_rx_ctl),
        .rgmii_rxd(rgmii_rxd),
        .gmii_clk(gmii_clk),
        .gmii_rx_dv(gmii_rx_dv),
        .gmii_rxd(gmii_rxd),
        .gmii_tx_en(gmii_tx_en),
        .gmii_txd(gmii_txd),
        .rgmii_txc(rgmii_txc),
        .rgmii_tx_ctl(rgmii_tx_ctl),
        .rgmii_txd(rgmii_txd)
    );

    // UDP/ARP 协议处理核心工作在 PHY 恢复出的 GMII 时钟域。
    udp_loopback_core #(
        .LOCAL_MAC(LOCAL_MAC),
        .LOCAL_IP(LOCAL_IP),
        .MAX_PAYLOAD_BYTES(MAX_PAYLOAD_BYTES)
    ) u_udp_loopback_core (
        .clk(gmii_clk),
        .rst_n(rst_n),
        .gmii_rx_dv(gmii_rx_dv),
        .gmii_rxd(gmii_rxd),
        .gmii_tx_en(gmii_tx_en),
        .gmii_txd(gmii_txd),
        .packet_seen(packet_seen),
        .packet_echoed(packet_echoed),
        .packet_dropped(packet_dropped)
    );

endmodule

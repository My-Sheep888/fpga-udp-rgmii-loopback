`timescale 1ns / 1ps

// GMII <-> RGMII 桥接模块：
// RX 方向把 RGMII 双沿 4bit 数据恢复成 GMII 单沿 8bit 数据；
// TX 方向把 GMII 单沿 8bit 数据打到 RGMII 双沿 4bit 管脚。
module gmii_to_rgmii_artix7 #(
    parameter integer IDELAY_VALUE = 0
)(
    input             idelay_clk_200m,
    input             rgmii_rxc,
    input             rgmii_rx_ctl,
    input      [3:0]  rgmii_rxd,
    output            gmii_clk,
    output            gmii_rx_dv,
    output     [7:0]  gmii_rxd,
    input             gmii_tx_en,
    input      [7:0]  gmii_txd,
    output            rgmii_txc,
    output            rgmii_tx_ctl,
    output     [3:0]  rgmii_txd
);

    // RGMII 接收：使用 PHY 提供的 RXC 采样 RX_CTL/RXD。
    rgmii_rx_artix7 #(
        .IDELAY_VALUE(IDELAY_VALUE)
    ) u_rgmii_rx (
        .idelay_clk_200m(idelay_clk_200m),
        .rgmii_rxc(rgmii_rxc),
        .rgmii_rx_ctl(rgmii_rx_ctl),
        .rgmii_rxd(rgmii_rxd),
        .gmii_rx_clk(gmii_clk),
        .gmii_rx_dv(gmii_rx_dv),
        .gmii_rxd(gmii_rxd)
    );

    // RGMII 发送：转发 GMII 时钟并把低/高 4bit 分别放在时钟双沿。
    rgmii_tx_artix7 u_rgmii_tx (
        .gmii_tx_clk(gmii_clk),
        .gmii_tx_en(gmii_tx_en),
        .gmii_txd(gmii_txd),
        .rgmii_txc(rgmii_txc),
        .rgmii_tx_ctl(rgmii_tx_ctl),
        .rgmii_txd(rgmii_txd)
    );

endmodule

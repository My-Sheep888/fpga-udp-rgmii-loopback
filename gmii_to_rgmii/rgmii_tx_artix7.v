`timescale 1ns / 1ps

// RGMII 发送模块：
// 用 ODDR 在时钟上升沿发送 gmii_txd[3:0]，下降沿发送 gmii_txd[7:4]。
module rgmii_tx_artix7(
    input             gmii_tx_clk,
    input             gmii_tx_en,
    input      [7:0]  gmii_txd,
    output            rgmii_txc,
    output            rgmii_tx_ctl,
    output     [3:0]  rgmii_txd
);

    // RGMII 要求转发时钟，ODDR 输出 1010... 形成 TXC。
    ODDR #(
        .DDR_CLK_EDGE("SAME_EDGE"),
        .INIT(1'b0),
        .SRTYPE("SYNC")
    ) u_oddr_txc (
        .Q(rgmii_txc),
        .C(gmii_tx_clk),
        .CE(1'b1),
        .D1(1'b1),
        .D2(1'b0),
        .R(1'b0),
        .S(1'b0)
    );

    // RGMII TX_CTL 在本设计里只表示 TX_EN，两个边沿输出相同值。
    ODDR #(
        .DDR_CLK_EDGE("SAME_EDGE"),
        .INIT(1'b0),
        .SRTYPE("SYNC")
    ) u_oddr_tx_ctl (
        .Q(rgmii_tx_ctl),
        .C(gmii_tx_clk),
        .CE(1'b1),
        .D1(gmii_tx_en),
        .D2(gmii_tx_en),
        .R(1'b0),
        .S(1'b0)
    );

    genvar i;
    generate
        for (i = 0; i < 4; i = i + 1) begin : g_tx_data
            // 每个 RGMII 数据管脚承载一个低位 bit 和一个高位 bit。
            ODDR #(
                .DDR_CLK_EDGE("SAME_EDGE"),
                .INIT(1'b0),
                .SRTYPE("SYNC")
            ) u_oddr_txd (
                .Q(rgmii_txd[i]),
                .C(gmii_tx_clk),
                .CE(1'b1),
                .D1(gmii_txd[i]),
                .D2(gmii_txd[i+4]),
                .R(1'b0),
                .S(1'b0)
            );
        end
    endgenerate

endmodule

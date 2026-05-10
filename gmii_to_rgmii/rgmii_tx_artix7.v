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

    wire txc_clk_90_unbuf;
    wire txc_clk_90;
    wire txc_clk_fb_unbuf;
    wire txc_clk_fb;

    // RGMII 发送方向需要让 TXC 相对 TXD/TX_CTL 延迟，使 PHY 在数据眼图中间采样。
    // 当前硬件按千兆链路验证，gmii_tx_clk 为 125MHz，90 度相移对应 2ns。
    MMCME2_BASE #(
        .BANDWIDTH("OPTIMIZED"),
        .CLKFBOUT_MULT_F(8.000),
        .CLKFBOUT_PHASE(0.000),
        .CLKIN1_PERIOD(8.000),
        .CLKOUT0_DIVIDE_F(8.000),
        .CLKOUT0_DUTY_CYCLE(0.500),
        .CLKOUT0_PHASE(90.000),
        .DIVCLK_DIVIDE(1),
        .REF_JITTER1(0.010),
        .STARTUP_WAIT("FALSE")
    ) u_txc_phase_mmcm (
        .CLKIN1(gmii_tx_clk),
        .CLKFBIN(txc_clk_fb),
        .CLKFBOUT(txc_clk_fb_unbuf),
        .CLKFBOUTB(),
        .CLKOUT0(txc_clk_90_unbuf),
        .CLKOUT0B(),
        .CLKOUT1(),
        .CLKOUT1B(),
        .CLKOUT2(),
        .CLKOUT2B(),
        .CLKOUT3(),
        .CLKOUT3B(),
        .CLKOUT4(),
        .CLKOUT5(),
        .CLKOUT6(),
        .LOCKED(),
        .PWRDWN(1'b0),
        .RST(1'b0)
    );

    BUFG u_txc_fb_bufg (
        .I(txc_clk_fb_unbuf),
        .O(txc_clk_fb)
    );

    BUFG u_txc_90_bufg (
        .I(txc_clk_90_unbuf),
        .O(txc_clk_90)
    );

    // RGMII 要求转发时钟，ODDR 输出 1010... 形成 TXC。
    ODDR #(
        .DDR_CLK_EDGE("SAME_EDGE"),
        .INIT(1'b0),
        .SRTYPE("SYNC")
    ) u_oddr_txc (
        .Q(rgmii_txc),
        .C(txc_clk_90),
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

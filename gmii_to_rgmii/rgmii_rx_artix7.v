`timescale 1ns / 1ps

// RGMII 接收模块：
// 使用输入延时和 IDDR，把 PHY 的 4bit DDR 数据恢复成内部 8bit GMII 数据。
module rgmii_rx_artix7 #(
    parameter integer IDELAY_VALUE = 0
)(
    input             idelay_clk_200m,
    input             rgmii_rxc,
    input             rgmii_rx_ctl,
    input      [3:0]  rgmii_rxd,
    output            gmii_rx_clk,
    output            gmii_rx_dv,
    output     [7:0]  gmii_rxd
);

    wire        rgmii_rxc_bufio;
    wire        rgmii_rx_ctl_delay;
    wire [3:0]  rgmii_rxd_delay;
    wire [1:0]  gmii_rx_dv_ddr;

    // RGMII RX_CTL 在上/下沿均为 1 时表示接收数据有效。
    assign gmii_rx_dv = gmii_rx_dv_ddr[0] & gmii_rx_dv_ddr[1];

    // BUFG 产生逻辑使用的 GMII 接收时钟。
    BUFG u_rx_clk_bufg (
        .I(rgmii_rxc),
        .O(gmii_rx_clk)
    );

    // BUFIO 产生 IO 采样使用的高速本地时钟。
    BUFIO u_rx_clk_bufio (
        .I(rgmii_rxc),
        .O(rgmii_rxc_bufio)
    );

    // IDELAYCTRL 需要 200MHz 参考时钟，负责校准输入延时单元。
    (* IODELAY_GROUP = "udp_loopback_rgmii" *)
    IDELAYCTRL u_idelayctrl (
        .RDY(),
        .REFCLK(idelay_clk_200m),
        .RST(1'b0)
    );

    // 对 RX_CTL 加固定延时，用来调整 RGMII 输入采样位置。
    (* IODELAY_GROUP = "udp_loopback_rgmii" *)
    IDELAYE2 #(
        .IDELAY_TYPE("FIXED"),
        .IDELAY_VALUE(IDELAY_VALUE),
        .REFCLK_FREQUENCY(200.0)
    ) u_delay_rx_ctl (
        .CNTVALUEOUT(),
        .DATAOUT(rgmii_rx_ctl_delay),
        .C(1'b0),
        .CE(1'b0),
        .CINVCTRL(1'b0),
        .CNTVALUEIN(5'd0),
        .DATAIN(1'b0),
        .IDATAIN(rgmii_rx_ctl),
        .INC(1'b0),
        .LD(1'b0),
        .LDPIPEEN(1'b0),
        .REGRST(1'b0)
    );

    // 双沿采样 RX_CTL，得到两个半字节对应的数据有效标志。
    IDDR #(
        .DDR_CLK_EDGE("SAME_EDGE_PIPELINED"),
        .INIT_Q1(1'b0),
        .INIT_Q2(1'b0),
        .SRTYPE("SYNC")
    ) u_iddr_rx_ctl (
        .Q1(gmii_rx_dv_ddr[0]),
        .Q2(gmii_rx_dv_ddr[1]),
        .C(rgmii_rxc_bufio),
        .CE(1'b1),
        .D(rgmii_rx_ctl_delay),
        .R(1'b0),
        .S(1'b0)
    );

    genvar i;
    generate
        for (i = 0; i < 4; i = i + 1) begin : g_rx_data
            // 每根 RGMII 数据线先经过固定输入延时。
            (* IODELAY_GROUP = "udp_loopback_rgmii" *)
            IDELAYE2 #(
                .IDELAY_TYPE("FIXED"),
                .IDELAY_VALUE(IDELAY_VALUE),
                .REFCLK_FREQUENCY(200.0)
            ) u_delay_rxd (
                .CNTVALUEOUT(),
                .DATAOUT(rgmii_rxd_delay[i]),
                .C(1'b0),
                .CE(1'b0),
                .CINVCTRL(1'b0),
                .CNTVALUEIN(5'd0),
                .DATAIN(1'b0),
                .IDATAIN(rgmii_rxd[i]),
                .INC(1'b0),
                .LD(1'b0),
                .LDPIPEEN(1'b0),
                .REGRST(1'b0)
            );

            // 上升沿采样低 4bit，下降沿采样高 4bit，合成 GMII 8bit。
            IDDR #(
                .DDR_CLK_EDGE("SAME_EDGE_PIPELINED"),
                .INIT_Q1(1'b0),
                .INIT_Q2(1'b0),
                .SRTYPE("SYNC")
            ) u_iddr_rxd (
                .Q1(gmii_rxd[i]),
                .Q2(gmii_rxd[i+4]),
                .C(rgmii_rxc_bufio),
                .CE(1'b1),
                .D(rgmii_rxd_delay[i]),
                .R(1'b0),
                .S(1'b0)
            );
        end
    endgenerate

endmodule

`timescale 1ns / 1ps

module rgmii_tx_artix7(
    input             gmii_tx_clk,
    input             gmii_tx_en,
    input      [7:0]  gmii_txd,
    output            rgmii_txc,
    output            rgmii_tx_ctl,
    output     [3:0]  rgmii_txd
);

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

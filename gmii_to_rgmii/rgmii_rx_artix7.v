`timescale 1ns / 1ps

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

    assign gmii_rx_dv = gmii_rx_dv_ddr[0] & gmii_rx_dv_ddr[1];

    BUFG u_rx_clk_bufg (
        .I(rgmii_rxc),
        .O(gmii_rx_clk)
    );

    BUFIO u_rx_clk_bufio (
        .I(rgmii_rxc),
        .O(rgmii_rxc_bufio)
    );

    (* IODELAY_GROUP = "udp_loopback_rgmii" *)
    IDELAYCTRL u_idelayctrl (
        .RDY(),
        .REFCLK(idelay_clk_200m),
        .RST(1'b0)
    );

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

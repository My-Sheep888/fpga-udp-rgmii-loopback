`timescale 1ns / 1ps

module udp_loopback_gmii #(
    parameter [47:0] LOCAL_MAC = 48'h00_11_22_33_44_66,
    parameter [31:0] LOCAL_IP  = {8'd192, 8'd168, 8'd6, 8'd12},
    parameter integer MAX_PAYLOAD_BYTES = 1472
)(
    input            clk,
    input            rst_n,
    input            gmii_rx_dv,
    input      [7:0] gmii_rxd,
    output           gmii_tx_en,
    output     [7:0] gmii_txd,
    output           packet_seen,
    output           packet_echoed,
    output           packet_dropped
);

    udp_loopback_core #(
        .LOCAL_MAC(LOCAL_MAC),
        .LOCAL_IP(LOCAL_IP),
        .MAX_PAYLOAD_BYTES(MAX_PAYLOAD_BYTES)
    ) u_udp_loopback_core (
        .clk(clk),
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

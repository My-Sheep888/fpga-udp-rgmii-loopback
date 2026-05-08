`timescale 1ns / 1ps

module udp_loopback_core #(
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

    wire frame_valid;
    wire [7:0] frame_data;
    wire frame_start;
    wire frame_last;
    wire frame_crc_ok;
    wire frame_crc_bad;

    wire payload_we;
    wire [10:0] payload_wr_addr;
    wire [7:0] payload_wr_data;
    wire udp_packet_valid;
    wire [47:0] udp_src_mac;
    wire [31:0] udp_src_ip;
    wire [15:0] udp_src_port;
    wire [15:0] udp_dst_port;
    wire [15:0] udp_payload_len;

    wire arp_request;
    wire arp_reply_unused;
    wire [47:0] arp_sender_mac;
    wire [31:0] arp_sender_ip;

    reg udp_start;
    reg arp_start;
    reg [47:0] reply_mac;
    reg [31:0] reply_ip;
    reg [15:0] reply_src_port;
    reg [15:0] reply_dst_port;
    reg [15:0] reply_len;
    reg packet_seen_r;
    reg packet_echoed_r;
    reg packet_dropped_r;

    wire [10:0] payload_rd_addr;
    wire [7:0] payload_rd_data;
    wire udp_tx_busy;
    wire udp_tx_done;
    wire udp_gmii_tx_en;
    wire [7:0] udp_gmii_txd;
    wire arp_tx_busy;
    wire arp_tx_done;
    wire arp_gmii_tx_en;
    wire [7:0] arp_gmii_txd;

    reg [7:0] payload_mem [0:MAX_PAYLOAD_BYTES-1];

    assign payload_rd_data = payload_mem[payload_rd_addr];
    assign gmii_tx_en = arp_tx_busy ? arp_gmii_tx_en : udp_gmii_tx_en;
    assign gmii_txd = arp_tx_busy ? arp_gmii_txd : udp_gmii_txd;
    assign packet_seen = packet_seen_r;
    assign packet_echoed = packet_echoed_r;
    assign packet_dropped = packet_dropped_r;

    eth_frame_rx u_eth_frame_rx (
        .clk(clk),
        .rst_n(rst_n),
        .gmii_rx_dv(gmii_rx_dv),
        .gmii_rxd(gmii_rxd),
        .frame_valid(frame_valid),
        .frame_data(frame_data),
        .frame_start(frame_start),
        .frame_last(frame_last),
        .frame_crc_ok(frame_crc_ok),
        .frame_crc_bad(frame_crc_bad)
    );

    udp_rx #(
        .LOCAL_MAC(LOCAL_MAC),
        .LOCAL_IP(LOCAL_IP),
        .MAX_PAYLOAD_BYTES(MAX_PAYLOAD_BYTES)
    ) u_udp_rx (
        .clk(clk),
        .rst_n(rst_n),
        .frame_valid(frame_valid),
        .frame_data(frame_data),
        .frame_start(frame_start),
        .frame_last(frame_last),
        .frame_crc_ok(frame_crc_ok),
        .payload_we(payload_we),
        .payload_addr(payload_wr_addr),
        .payload_data(payload_wr_data),
        .udp_packet_valid(udp_packet_valid),
        .src_mac(udp_src_mac),
        .src_ip(udp_src_ip),
        .src_port(udp_src_port),
        .dst_port(udp_dst_port),
        .payload_len(udp_payload_len)
    );

    arp_rx #(
        .LOCAL_MAC(LOCAL_MAC),
        .LOCAL_IP(LOCAL_IP)
    ) u_arp_rx (
        .clk(clk),
        .rst_n(rst_n),
        .frame_valid(frame_valid),
        .frame_data(frame_data),
        .frame_start(frame_start),
        .frame_last(frame_last),
        .frame_crc_ok(frame_crc_ok),
        .arp_request(arp_request),
        .arp_reply(arp_reply_unused),
        .sender_mac(arp_sender_mac),
        .sender_ip(arp_sender_ip)
    );

    udp_tx #(
        .LOCAL_MAC(LOCAL_MAC),
        .LOCAL_IP(LOCAL_IP)
    ) u_udp_tx (
        .clk(clk),
        .rst_n(rst_n),
        .tx_start(udp_start),
        .dst_mac(reply_mac),
        .dst_ip(reply_ip),
        .src_port(reply_src_port),
        .dst_port(reply_dst_port),
        .payload_len(reply_len),
        .payload_rd_addr(payload_rd_addr),
        .payload_rd_data(payload_rd_data),
        .tx_busy(udp_tx_busy),
        .tx_done(udp_tx_done),
        .gmii_tx_en(udp_gmii_tx_en),
        .gmii_txd(udp_gmii_txd)
    );

    arp_tx #(
        .LOCAL_MAC(LOCAL_MAC),
        .LOCAL_IP(LOCAL_IP)
    ) u_arp_tx (
        .clk(clk),
        .rst_n(rst_n),
        .reply_start(arp_start),
        .target_mac(arp_sender_mac),
        .target_ip(arp_sender_ip),
        .tx_busy(arp_tx_busy),
        .tx_done(arp_tx_done),
        .gmii_tx_en(arp_gmii_tx_en),
        .gmii_txd(arp_gmii_txd)
    );

    always @(posedge clk) begin
        if (payload_we)
            payload_mem[payload_wr_addr] <= payload_wr_data;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            udp_start <= 1'b0;
            arp_start <= 1'b0;
            reply_mac <= 48'd0;
            reply_ip <= 32'd0;
            reply_src_port <= 16'd0;
            reply_dst_port <= 16'd0;
            reply_len <= 16'd0;
            packet_seen_r <= 1'b0;
            packet_echoed_r <= 1'b0;
            packet_dropped_r <= 1'b0;
        end else begin
            udp_start <= 1'b0;
            arp_start <= 1'b0;
            packet_seen_r <= 1'b0;
            packet_echoed_r <= udp_tx_done || arp_tx_done;
            packet_dropped_r <= frame_crc_bad;

            if (arp_request && !udp_tx_busy && !arp_tx_busy) begin
                arp_start <= 1'b1;
                packet_seen_r <= 1'b1;
            end else if (udp_packet_valid && !udp_tx_busy && !arp_tx_busy) begin
                reply_mac <= udp_src_mac;
                reply_ip <= udp_src_ip;
                reply_src_port <= udp_dst_port;
                reply_dst_port <= udp_src_port;
                reply_len <= udp_payload_len;
                udp_start <= 1'b1;
                packet_seen_r <= 1'b1;
            end
        end
    end

endmodule

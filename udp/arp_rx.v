`timescale 1ns / 1ps

// ARP 接收解析模块：
// 从以太网帧流中识别 ARP request/reply，并提取发送方 MAC/IP。
module arp_rx #(
    parameter [47:0] LOCAL_MAC = 48'h00_11_22_33_44_66,
    parameter [31:0] LOCAL_IP  = {8'd192, 8'd168, 8'd6, 8'd12}
)(
    input             clk,
    input             rst_n,
    input             frame_valid,
    input      [7:0]  frame_data,
    input             frame_start,
    input             frame_last,
    input             frame_crc_ok,

    output reg        arp_request,
    output reg        arp_reply,
    output reg [47:0] sender_mac,
    output reg [31:0] sender_ip
);

    // index 是 ARP 帧在 Ethernet payload 内的固定字节偏移。
    reg [15:0] index;
    reg [47:0] dst_mac;
    reg [15:0] eth_type;
    reg [15:0] oper;
    reg [31:0] target_ip;
    reg        is_arp;

    // 流式解析 ARP 报文，帧尾 CRC 正确后再输出请求/应答脉冲。
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            index <= 16'd0;
            dst_mac <= 48'd0;
            eth_type <= 16'd0;
            oper <= 16'd0;
            target_ip <= 32'd0;
            sender_mac <= 48'd0;
            sender_ip <= 32'd0;
            is_arp <= 1'b0;
            arp_request <= 1'b0;
            arp_reply <= 1'b0;
        end else begin
            arp_request <= 1'b0;
            arp_reply <= 1'b0;

            if (frame_start) begin
                // 新帧开始时清空上一帧的解析结果。
                index <= 16'd0;
                dst_mac <= 48'd0;
                eth_type <= 16'd0;
                oper <= 16'd0;
                target_ip <= 32'd0;
                sender_mac <= 48'd0;
                sender_ip <= 32'd0;
                is_arp <= 1'b0;
            end

            if (frame_valid) begin
                case (index)
                    // Ethernet header：目的 MAC 和类型字段。
                    16'd0:  dst_mac[47:40] <= frame_data;
                    16'd1:  dst_mac[39:32] <= frame_data;
                    16'd2:  dst_mac[31:24] <= frame_data;
                    16'd3:  dst_mac[23:16] <= frame_data;
                    16'd4:  dst_mac[15:8] <= frame_data;
                    16'd5:  dst_mac[7:0] <= frame_data;
                    16'd12: eth_type[15:8] <= frame_data;
                    16'd13: begin
                        eth_type[7:0] <= frame_data;
                        is_arp <= (eth_type[15:8] == 8'h08 && frame_data == 8'h06);
                    end
                    // ARP payload：操作码、发送方地址、目标 IP。
                    16'd20: oper[15:8] <= frame_data;
                    16'd21: oper[7:0] <= frame_data;
                    16'd22: sender_mac[47:40] <= frame_data;
                    16'd23: sender_mac[39:32] <= frame_data;
                    16'd24: sender_mac[31:24] <= frame_data;
                    16'd25: sender_mac[23:16] <= frame_data;
                    16'd26: sender_mac[15:8] <= frame_data;
                    16'd27: sender_mac[7:0] <= frame_data;
                    16'd28: sender_ip[31:24] <= frame_data;
                    16'd29: sender_ip[23:16] <= frame_data;
                    16'd30: sender_ip[15:8] <= frame_data;
                    16'd31: sender_ip[7:0] <= frame_data;
                    16'd38: target_ip[31:24] <= frame_data;
                    16'd39: target_ip[23:16] <= frame_data;
                    16'd40: target_ip[15:8] <= frame_data;
                    16'd41: target_ip[7:0] <= frame_data;
                    default: begin end
                endcase

                index <= index + 1'b1;
            end

            // 只响应发给本机 IP 的 ARP 帧，并且要求以太网 CRC 正确。
            if (frame_last && frame_crc_ok && is_arp &&
                ((dst_mac == LOCAL_MAC) || (dst_mac == 48'hff_ff_ff_ff_ff_ff)) &&
                (target_ip == LOCAL_IP)) begin
                if (oper == 16'h0001)
                    arp_request <= 1'b1;
                else if (oper == 16'h0002)
                    arp_reply <= 1'b1;
            end
        end
    end

endmodule

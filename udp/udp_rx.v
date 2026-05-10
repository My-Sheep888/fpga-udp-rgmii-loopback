`timescale 1ns / 1ps

// UDP 接收解析模块：
// 从以太网帧流中提取 IPv4/UDP 头，确认是发给本机的 UDP 包后输出 payload。
module udp_rx #(
    parameter [47:0] LOCAL_MAC = 48'h00_11_22_33_44_66,
    parameter [31:0] LOCAL_IP  = {8'd192, 8'd168, 8'd6, 8'd12},
    parameter integer MAX_PAYLOAD_BYTES = 1472
)(
    input             clk,
    input             rst_n,
    input             frame_valid,
    input      [7:0]  frame_data,
    input             frame_start,
    input             frame_last,
    input             frame_crc_ok,

    output reg        payload_we,
    output reg [10:0] payload_addr,
    output reg [7:0]  payload_data,
    output reg        udp_packet_valid,
    output reg [47:0] src_mac,
    output reg [31:0] src_ip,
    output reg [15:0] src_port,
    output reg [15:0] dst_port,
    output reg [15:0] payload_len
);

    // index 对应不含前导码和 FCS 的以太网帧内字节位置。
    reg [15:0] index;
    reg [47:0] dst_mac;
    reg [15:0] eth_type;
    reg [7:0]  ip_vihl;
    reg [15:0] ip_total_len;
    reg [7:0]  ip_proto;
    reg [31:0] dst_ip;
    reg [15:0] udp_len;
    reg        is_udp;
    reg        header_ok;
    reg [15:0] payload_count;
    wire [15:0] frame_index = frame_start ? 16'd0 : index;

    // 单时钟流式解析：一边接收 frame_data，一边按固定偏移锁存协议字段。
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            index <= 16'd0;
            dst_mac <= 48'd0;
            src_mac <= 48'd0;
            eth_type <= 16'd0;
            ip_vihl <= 8'd0;
            ip_total_len <= 16'd0;
            ip_proto <= 8'd0;
            src_ip <= 32'd0;
            dst_ip <= 32'd0;
            src_port <= 16'd0;
            dst_port <= 16'd0;
            udp_len <= 16'd0;
            payload_len <= 16'd0;
            payload_count <= 16'd0;
            is_udp <= 1'b0;
            header_ok <= 1'b0;
            payload_we <= 1'b0;
            payload_addr <= 11'd0;
            payload_data <= 8'd0;
            udp_packet_valid <= 1'b0;
        end else begin
            payload_we <= 1'b0;
            udp_packet_valid <= 1'b0;

            if (frame_start) begin
                // 新帧开始时清空上一帧的解析状态。
                index <= 16'd0;
                dst_mac <= 48'd0;
                src_mac <= 48'd0;
                eth_type <= 16'd0;
                ip_vihl <= 8'd0;
                ip_total_len <= 16'd0;
                ip_proto <= 8'd0;
                src_ip <= 32'd0;
                dst_ip <= 32'd0;
                src_port <= 16'd0;
                dst_port <= 16'd0;
                udp_len <= 16'd0;
                payload_len <= 16'd0;
                payload_count <= 16'd0;
                is_udp <= 1'b0;
                header_ok <= 1'b0;
            end

            if (frame_valid) begin
                case (frame_index)
                    // Ethernet header：目的 MAC、源 MAC、类型。
                    16'd0:  dst_mac[47:40] <= frame_data;
                    16'd1:  dst_mac[39:32] <= frame_data;
                    16'd2:  dst_mac[31:24] <= frame_data;
                    16'd3:  dst_mac[23:16] <= frame_data;
                    16'd4:  dst_mac[15:8] <= frame_data;
                    16'd5:  dst_mac[7:0] <= frame_data;
                    16'd6:  src_mac[47:40] <= frame_data;
                    16'd7:  src_mac[39:32] <= frame_data;
                    16'd8:  src_mac[31:24] <= frame_data;
                    16'd9:  src_mac[23:16] <= frame_data;
                    16'd10: src_mac[15:8] <= frame_data;
                    16'd11: src_mac[7:0] <= frame_data;
                    16'd12: eth_type[15:8] <= frame_data;
                    16'd13: eth_type[7:0] <= frame_data;
                    // IPv4 header：当前只支持无 IP options 的 IPv4 UDP 包。
                    16'd14: ip_vihl <= frame_data;
                    16'd16: ip_total_len[15:8] <= frame_data;
                    16'd17: ip_total_len[7:0] <= frame_data;
                    16'd23: ip_proto <= frame_data;
                    16'd26: src_ip[31:24] <= frame_data;
                    16'd27: src_ip[23:16] <= frame_data;
                    16'd28: src_ip[15:8] <= frame_data;
                    16'd29: src_ip[7:0] <= frame_data;
                    16'd30: dst_ip[31:24] <= frame_data;
                    16'd31: dst_ip[23:16] <= frame_data;
                    16'd32: dst_ip[15:8] <= frame_data;
                    16'd33: dst_ip[7:0] <= frame_data;
                    // UDP header：记录源/目的端口和 UDP 长度。
                    16'd34: src_port[15:8] <= frame_data;
                    16'd35: src_port[7:0] <= frame_data;
                    16'd36: dst_port[15:8] <= frame_data;
                    16'd37: dst_port[7:0] <= frame_data;
                    16'd38: udp_len[15:8] <= frame_data;
                    16'd39: udp_len[7:0] <= frame_data;
                    16'd41: begin
                        payload_len <= udp_len - 16'd8;
                        // 到 UDP 头结束时，前面的关键头字段已经收齐，可以判定是否合法。
                        header_ok <= ((dst_mac == LOCAL_MAC) || (dst_mac == 48'hff_ff_ff_ff_ff_ff)) &&
                                     (eth_type == 16'h0800) &&
                                     (ip_vihl == 8'h45) &&
                                     (ip_proto == 8'd17) &&
                                     (dst_ip == LOCAL_IP) &&
                                     (udp_len >= 16'd8) &&
                                     ((udp_len - 16'd8) <= MAX_PAYLOAD_BYTES) &&
                                     (ip_total_len == udp_len + 16'd20);
                        is_udp <= 1'b1;
                        payload_count <= 16'd0;
                    end
                    default: begin
                        // header_ok 成立后，把 UDP payload 顺序写入外部缓存。
                        if (is_udp && header_ok && frame_index >= 16'd42 && payload_count < payload_len) begin
                            payload_we <= 1'b1;
                            payload_addr <= payload_count[10:0];
                            payload_data <= frame_data;
                            payload_count <= payload_count + 1'b1;
                        end
                    end
                endcase

                index <= frame_index + 1'b1;
            end

            // 一帧结束且 CRC 正确、payload 长度匹配时，给核心一个 UDP 包有效脉冲。
            if (frame_last && frame_crc_ok && is_udp && header_ok && payload_count == payload_len)
                udp_packet_valid <= 1'b1;
        end
    end

endmodule

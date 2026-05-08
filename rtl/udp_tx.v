`timescale 1ns / 1ps

module udp_tx #(
    parameter [47:0] LOCAL_MAC = 48'h00_11_22_33_44_66,
    parameter [31:0] LOCAL_IP  = {8'd192, 8'd168, 8'd6, 8'd12}
)(
    input             clk,
    input             rst_n,
    input             tx_start,
    input      [47:0] dst_mac,
    input      [31:0] dst_ip,
    input      [15:0] src_port,
    input      [15:0] dst_port,
    input      [15:0] payload_len,
    output reg [10:0] payload_rd_addr,
    input      [7:0]  payload_rd_data,

    output reg        tx_busy,
    output reg        tx_done,
    output reg        gmii_tx_en,
    output reg [7:0]  gmii_txd
);

    localparam S_IDLE = 3'd0;
    localparam S_PREAMBLE = 3'd1;
    localparam S_HEADER = 3'd2;
    localparam S_PAYLOAD = 3'd3;
    localparam S_PAD = 3'd4;
    localparam S_FCS = 3'd5;
    localparam S_IFG = 3'd6;

    reg [2:0] state;
    reg [15:0] index;
    reg [31:0] crc;
    reg [31:0] fcs;
    reg [47:0] dst_mac_latched;
    reg [31:0] dst_ip_latched;
    reg [15:0] src_port_latched;
    reg [15:0] dst_port_latched;
    reg [15:0] payload_len_latched;
    reg [15:0] total_len;
    reg [15:0] udp_len;
    reg [15:0] pad_len;
    reg [15:0] ip_checksum;

    function [31:0] eth_crc32_next_func;
        input [7:0] data;
        input [31:0] crc_i;
        integer i;
        reg [31:0] c;
        begin
            c = crc_i ^ {24'd0, data};
            for (i = 0; i < 8; i = i + 1) begin
                if (c[0])
                    c = (c >> 1) ^ 32'hedb88320;
                else
                    c = (c >> 1);
            end
            eth_crc32_next_func = c;
        end
    endfunction

    function [31:0] eth_crc32_fcs_func;
        input [31:0] crc_i;
        begin
            eth_crc32_fcs_func = ~crc_i;
        end
    endfunction

    function [15:0] calc_ip_checksum;
        input [15:0] total_len_i;
        input [31:0] dst_ip_i;
        reg [31:0] sum;
        begin
            sum = 32'd0;
            sum = sum + 16'h4500;
            sum = sum + total_len_i;
            sum = sum + 16'h0000;
            sum = sum + 16'h4000;
            sum = sum + 16'h4011;
            sum = sum + LOCAL_IP[31:16];
            sum = sum + LOCAL_IP[15:0];
            sum = sum + dst_ip_i[31:16];
            sum = sum + dst_ip_i[15:0];
            sum = sum[15:0] + sum[31:16];
            sum = sum[15:0] + sum[31:16];
            calc_ip_checksum = ~sum[15:0];
        end
    endfunction

    function [7:0] header_byte;
        input [7:0] idx;
        begin
            case (idx)
                8'd0:  header_byte = dst_mac_latched[47:40];
                8'd1:  header_byte = dst_mac_latched[39:32];
                8'd2:  header_byte = dst_mac_latched[31:24];
                8'd3:  header_byte = dst_mac_latched[23:16];
                8'd4:  header_byte = dst_mac_latched[15:8];
                8'd5:  header_byte = dst_mac_latched[7:0];
                8'd6:  header_byte = LOCAL_MAC[47:40];
                8'd7:  header_byte = LOCAL_MAC[39:32];
                8'd8:  header_byte = LOCAL_MAC[31:24];
                8'd9:  header_byte = LOCAL_MAC[23:16];
                8'd10: header_byte = LOCAL_MAC[15:8];
                8'd11: header_byte = LOCAL_MAC[7:0];
                8'd12: header_byte = 8'h08;
                8'd13: header_byte = 8'h00;
                8'd14: header_byte = 8'h45;
                8'd15: header_byte = 8'h00;
                8'd16: header_byte = total_len[15:8];
                8'd17: header_byte = total_len[7:0];
                8'd18: header_byte = 8'h00;
                8'd19: header_byte = 8'h00;
                8'd20: header_byte = 8'h40;
                8'd21: header_byte = 8'h00;
                8'd22: header_byte = 8'h40;
                8'd23: header_byte = 8'h11;
                8'd24: header_byte = ip_checksum[15:8];
                8'd25: header_byte = ip_checksum[7:0];
                8'd26: header_byte = LOCAL_IP[31:24];
                8'd27: header_byte = LOCAL_IP[23:16];
                8'd28: header_byte = LOCAL_IP[15:8];
                8'd29: header_byte = LOCAL_IP[7:0];
                8'd30: header_byte = dst_ip_latched[31:24];
                8'd31: header_byte = dst_ip_latched[23:16];
                8'd32: header_byte = dst_ip_latched[15:8];
                8'd33: header_byte = dst_ip_latched[7:0];
                8'd34: header_byte = src_port_latched[15:8];
                8'd35: header_byte = src_port_latched[7:0];
                8'd36: header_byte = dst_port_latched[15:8];
                8'd37: header_byte = dst_port_latched[7:0];
                8'd38: header_byte = udp_len[15:8];
                8'd39: header_byte = udp_len[7:0];
                8'd40: header_byte = 8'h00;
                8'd41: header_byte = 8'h00;
                default: header_byte = 8'h00;
            endcase
        end
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            index <= 16'd0;
            crc <= 32'hffff_ffff;
            fcs <= 32'd0;
            dst_mac_latched <= 48'd0;
            dst_ip_latched <= 32'd0;
            src_port_latched <= 16'd0;
            dst_port_latched <= 16'd0;
            payload_len_latched <= 16'd0;
            total_len <= 16'd0;
            udp_len <= 16'd0;
            pad_len <= 16'd0;
            ip_checksum <= 16'd0;
            payload_rd_addr <= 11'd0;
            tx_busy <= 1'b0;
            tx_done <= 1'b0;
            gmii_tx_en <= 1'b0;
            gmii_txd <= 8'd0;
        end else begin
            tx_done <= 1'b0;
            case (state)
                S_IDLE: begin
                    gmii_tx_en <= 1'b0;
                    gmii_txd <= 8'd0;
                    tx_busy <= 1'b0;
                    index <= 16'd0;
                    payload_rd_addr <= 11'd0;
                    if (tx_start) begin
                        dst_mac_latched <= dst_mac;
                        dst_ip_latched <= dst_ip;
                        src_port_latched <= src_port;
                        dst_port_latched <= dst_port;
                        payload_len_latched <= payload_len;
                        total_len <= payload_len + 16'd28;
                        udp_len <= payload_len + 16'd8;
                        if (payload_len < 16'd18)
                            pad_len <= 16'd18 - payload_len;
                        else
                            pad_len <= 16'd0;
                        ip_checksum <= calc_ip_checksum(payload_len + 16'd28, dst_ip);
                        crc <= 32'hffff_ffff;
                        tx_busy <= 1'b1;
                        state <= S_PREAMBLE;
                    end
                end

                S_PREAMBLE: begin
                    gmii_tx_en <= 1'b1;
                    gmii_txd <= (index < 16'd7) ? 8'h55 : 8'hd5;
                    if (index == 16'd7) begin
                        index <= 16'd0;
                        state <= S_HEADER;
                    end else begin
                        index <= index + 1'b1;
                    end
                end

                S_HEADER: begin
                    gmii_tx_en <= 1'b1;
                    gmii_txd <= header_byte(index[7:0]);
                    crc <= eth_crc32_next_func(header_byte(index[7:0]), crc);
                    if (index == 16'd41) begin
                        index <= 16'd0;
                        payload_rd_addr <= 11'd0;
                        if (payload_len_latched == 16'd0) begin
                            state <= S_FCS;
                            if (pad_len == 16'd0)
                                fcs <= eth_crc32_fcs_func(eth_crc32_next_func(header_byte(index[7:0]), crc));
                            else
                                state <= S_PAD;
                        end else begin
                            state <= S_PAYLOAD;
                        end
                    end else begin
                        index <= index + 1'b1;
                    end
                end

                S_PAYLOAD: begin
                    gmii_tx_en <= 1'b1;
                    gmii_txd <= payload_rd_data;
                    crc <= eth_crc32_next_func(payload_rd_data, crc);
                    if (index == payload_len_latched - 1'b1) begin
                        index <= 16'd0;
                        if (pad_len == 16'd0) begin
                            fcs <= eth_crc32_fcs_func(eth_crc32_next_func(payload_rd_data, crc));
                            state <= S_FCS;
                        end else begin
                            state <= S_PAD;
                        end
                    end else begin
                        index <= index + 1'b1;
                        payload_rd_addr <= payload_rd_addr + 1'b1;
                    end
                end

                S_PAD: begin
                    gmii_tx_en <= 1'b1;
                    gmii_txd <= 8'h00;
                    crc <= eth_crc32_next_func(8'h00, crc);
                    if (index == pad_len - 1'b1) begin
                        fcs <= eth_crc32_fcs_func(eth_crc32_next_func(8'h00, crc));
                        index <= 16'd0;
                        state <= S_FCS;
                    end else begin
                        index <= index + 1'b1;
                    end
                end

                S_FCS: begin
                    gmii_tx_en <= 1'b1;
                    case (index)
                        16'd0: gmii_txd <= fcs[7:0];
                        16'd1: gmii_txd <= fcs[15:8];
                        16'd2: gmii_txd <= fcs[23:16];
                        default: gmii_txd <= fcs[31:24];
                    endcase
                    if (index == 16'd3) begin
                        index <= 16'd0;
                        tx_done <= 1'b1;
                        state <= S_IFG;
                    end else begin
                        index <= index + 1'b1;
                    end
                end

                S_IFG: begin
                    gmii_tx_en <= 1'b0;
                    gmii_txd <= 8'd0;
                    if (index == 16'd11)
                        state <= S_IDLE;
                    else
                        index <= index + 1'b1;
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule

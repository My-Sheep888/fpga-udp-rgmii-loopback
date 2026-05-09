`timescale 1ns / 1ps

module arp_tx #(
    parameter [47:0] LOCAL_MAC = 48'h00_11_22_33_44_66,
    parameter [31:0] LOCAL_IP  = {8'd192, 8'd168, 8'd6, 8'd12}
)(
    input             clk,
    input             rst_n,
    input             reply_start,
    input      [47:0] target_mac,
    input      [31:0] target_ip,

    output reg        tx_busy,
    output reg        tx_done,
    output reg        gmii_tx_en,
    output reg [7:0]  gmii_txd
);

    localparam S_IDLE = 3'd0;
    localparam S_PREAMBLE = 3'd1;
    localparam S_FRAME = 3'd2;
    localparam S_FCS = 3'd3;
    localparam S_IFG = 3'd4;

    reg [2:0] state;
    reg [7:0] index;
    reg [31:0] crc;
    reg [31:0] fcs;
    reg [47:0] dst_mac_latched;
    reg [31:0] dst_ip_latched;

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

    function [7:0] arp_byte;
        input [7:0] idx;
        begin
            case (idx)
                8'd0:  arp_byte = dst_mac_latched[47:40];
                8'd1:  arp_byte = dst_mac_latched[39:32];
                8'd2:  arp_byte = dst_mac_latched[31:24];
                8'd3:  arp_byte = dst_mac_latched[23:16];
                8'd4:  arp_byte = dst_mac_latched[15:8];
                8'd5:  arp_byte = dst_mac_latched[7:0];
                8'd6:  arp_byte = LOCAL_MAC[47:40];
                8'd7:  arp_byte = LOCAL_MAC[39:32];
                8'd8:  arp_byte = LOCAL_MAC[31:24];
                8'd9:  arp_byte = LOCAL_MAC[23:16];
                8'd10: arp_byte = LOCAL_MAC[15:8];
                8'd11: arp_byte = LOCAL_MAC[7:0];
                8'd12: arp_byte = 8'h08;
                8'd13: arp_byte = 8'h06;
                8'd14: arp_byte = 8'h00;
                8'd15: arp_byte = 8'h01;
                8'd16: arp_byte = 8'h08;
                8'd17: arp_byte = 8'h00;
                8'd18: arp_byte = 8'h06;
                8'd19: arp_byte = 8'h04;
                8'd20: arp_byte = 8'h00;
                8'd21: arp_byte = 8'h02;
                8'd22: arp_byte = LOCAL_MAC[47:40];
                8'd23: arp_byte = LOCAL_MAC[39:32];
                8'd24: arp_byte = LOCAL_MAC[31:24];
                8'd25: arp_byte = LOCAL_MAC[23:16];
                8'd26: arp_byte = LOCAL_MAC[15:8];
                8'd27: arp_byte = LOCAL_MAC[7:0];
                8'd28: arp_byte = LOCAL_IP[31:24];
                8'd29: arp_byte = LOCAL_IP[23:16];
                8'd30: arp_byte = LOCAL_IP[15:8];
                8'd31: arp_byte = LOCAL_IP[7:0];
                8'd32: arp_byte = dst_mac_latched[47:40];
                8'd33: arp_byte = dst_mac_latched[39:32];
                8'd34: arp_byte = dst_mac_latched[31:24];
                8'd35: arp_byte = dst_mac_latched[23:16];
                8'd36: arp_byte = dst_mac_latched[15:8];
                8'd37: arp_byte = dst_mac_latched[7:0];
                8'd38: arp_byte = dst_ip_latched[31:24];
                8'd39: arp_byte = dst_ip_latched[23:16];
                8'd40: arp_byte = dst_ip_latched[15:8];
                8'd41: arp_byte = dst_ip_latched[7:0];
                default: arp_byte = 8'h00;
            endcase
        end
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            index <= 8'd0;
            crc <= 32'hffff_ffff;
            fcs <= 32'd0;
            dst_mac_latched <= 48'd0;
            dst_ip_latched <= 32'd0;
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
                    index <= 8'd0;
                    if (reply_start) begin
                        dst_mac_latched <= target_mac;
                        dst_ip_latched <= target_ip;
                        crc <= 32'hffff_ffff;
                        tx_busy <= 1'b1;
                        state <= S_PREAMBLE;
                    end
                end

                S_PREAMBLE: begin
                    gmii_tx_en <= 1'b1;
                    gmii_txd <= (index < 8'd7) ? 8'h55 : 8'hd5;
                    if (index == 8'd7) begin
                        index <= 8'd0;
                        state <= S_FRAME;
                    end else begin
                        index <= index + 1'b1;
                    end
                end

                S_FRAME: begin
                    gmii_tx_en <= 1'b1;
                    gmii_txd <= arp_byte(index);
                    crc <= eth_crc32_next_func(arp_byte(index), crc);
                    if (index == 8'd59) begin
                        fcs <= eth_crc32_fcs_func(eth_crc32_next_func(arp_byte(index), crc));
                        index <= 8'd0;
                        state <= S_FCS;
                    end else begin
                        index <= index + 1'b1;
                    end
                end

                S_FCS: begin
                    gmii_tx_en <= 1'b1;
                    case (index)
                        8'd0: gmii_txd <= fcs[7:0];
                        8'd1: gmii_txd <= fcs[15:8];
                        8'd2: gmii_txd <= fcs[23:16];
                        default: gmii_txd <= fcs[31:24];
                    endcase
                    if (index == 8'd3) begin
                        index <= 8'd0;
                        tx_done <= 1'b1;
                        state <= S_IFG;
                    end else begin
                        index <= index + 1'b1;
                    end
                end

                S_IFG: begin
                    gmii_tx_en <= 1'b0;
                    gmii_txd <= 8'd0;
                    if (index == 8'd11)
                        state <= S_IDLE;
                    else
                        index <= index + 1'b1;
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule

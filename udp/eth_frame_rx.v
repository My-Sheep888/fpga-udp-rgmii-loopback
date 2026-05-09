`timescale 1ns / 1ps

// 以太网帧接收模块：
// 识别 GMII 前导码/SFD，剥离最后 4 字节 FCS，并对帧数据做 CRC32 校验。
module eth_frame_rx(
    input            clk,
    input            rst_n,
    input            gmii_rx_dv,
    input      [7:0] gmii_rxd,

    output reg       frame_valid,
    output reg [7:0] frame_data,
    output reg       frame_start,
    output reg       frame_last,
    output reg       frame_crc_ok,
    output reg       frame_crc_bad
);

    // 接收状态：等待前导码、检查 SFD、输出帧数据。
    localparam S_IDLE = 2'd0;
    localparam S_PREAMBLE = 2'd1;
    localparam S_FRAME = 2'd2;

    reg [1:0] state;
    reg [3:0] pre_cnt;
    reg [31:0] crc;
    reg [31:0] tail;
    reg [15:0] byte_count;
    reg gmii_rx_dv_d;

    // gmii_rx_dv 下降沿表示一帧结束。
    wire rx_fall = gmii_rx_dv_d && !gmii_rx_dv;
    wire [31:0] expected_fcs = eth_crc32_fcs_func(crc);

    // 以太网 CRC32 逐字节更新函数，采用低位先行的反射多项式。
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

    // FCS 是 CRC 寄存器最终值按位取反后发送。
    function [31:0] eth_crc32_fcs_func;
        input [31:0] crc_i;
        begin
            eth_crc32_fcs_func = ~crc_i;
        end
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            pre_cnt <= 4'd0;
            crc <= 32'hffff_ffff;
            tail <= 32'd0;
            byte_count <= 16'd0;
            gmii_rx_dv_d <= 1'b0;
            frame_valid <= 1'b0;
            frame_data <= 8'd0;
            frame_start <= 1'b0;
            frame_last <= 1'b0;
            frame_crc_ok <= 1'b0;
            frame_crc_bad <= 1'b0;
        end else begin
            gmii_rx_dv_d <= gmii_rx_dv;
            frame_valid <= 1'b0;
            frame_start <= 1'b0;
            frame_last <= 1'b0;
            frame_crc_ok <= 1'b0;
            frame_crc_bad <= 1'b0;

            case (state)
                S_IDLE: begin
                    // 空闲时等待第一个 0x55 前导码字节。
                    pre_cnt <= 4'd0;
                    byte_count <= 16'd0;
                    crc <= 32'hffff_ffff;
                    tail <= 32'd0;
                    if (gmii_rx_dv && gmii_rxd == 8'h55) begin
                        pre_cnt <= 4'd1;
                        state <= S_PREAMBLE;
                    end
                end

                S_PREAMBLE: begin
                    // 需要连续 7 个 0x55 后跟 0xd5，才认为后面是有效帧。
                    if (!gmii_rx_dv) begin
                        state <= S_IDLE;
                    end else if (gmii_rxd == 8'h55 && pre_cnt < 4'd7) begin
                        pre_cnt <= pre_cnt + 1'b1;
                    end else if (gmii_rxd == 8'hd5 && pre_cnt == 4'd7) begin
                        byte_count <= 16'd0;
                        crc <= 32'hffff_ffff;
                        tail <= 32'd0;
                        state <= S_FRAME;
                    end else begin
                        state <= S_IDLE;
                    end
                end

                S_FRAME: begin
                    if (gmii_rx_dv) begin
                        // tail 保留最近 4 字节，延迟输出可以把 FCS 留在模块内部。
                        tail <= {gmii_rxd, tail[31:8]};
                        if (byte_count >= 16'd4) begin
                            frame_valid <= 1'b1;
                            frame_data <= tail[7:0];
                            frame_start <= (byte_count == 16'd4);
                            crc <= eth_crc32_next_func(tail[7:0], crc);
                        end
                        byte_count <= byte_count + 1'b1;
                    end

                    if (rx_fall) begin
                        // 帧结束时比较接收到的 FCS 和本地计算结果。
                        state <= S_IDLE;
                        if (byte_count >= 16'd64) begin
                            frame_last <= 1'b1;
                            if (tail == expected_fcs)
                                frame_crc_ok <= 1'b1;
                            else
                                frame_crc_bad <= 1'b1;
                        end else begin
                            frame_crc_bad <= 1'b1;
                        end
                    end
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule

`timescale 1ns / 1ps

// GMII UDP 回环 testbench：
// 构造一帧带 FCS 的 UDP 包送入 DUT，并检查 DUT 发出的回包字段和 payload。
module tb_udp_loopback_gmii;

    reg clk;
    reg rst_n;
    reg gmii_rx_dv;
    reg [7:0] gmii_rxd;
    wire gmii_tx_en;
    wire [7:0] gmii_txd;
    wire packet_seen;
    wire packet_echoed;
    wire packet_dropped;

    integer tx_count;
    integer init_index;
    reg [7:0] tx_bytes [0:255];
    reg [31:0] send_crc;

    localparam [47:0] LOCAL_MAC = 48'h00_11_22_33_44_66;
    localparam [47:0] HOST_MAC  = 48'h02_12_34_56_78_9a;
    localparam [31:0] LOCAL_IP  = {8'd192, 8'd168, 8'd6, 8'd12};
    localparam [31:0] HOST_IP   = {8'd192, 8'd168, 8'd6, 8'd100};

    // DUT 使用 GMII 顶层，便于在不依赖 RGMII 原语仿真的情况下验证协议逻辑。
    udp_loopback_gmii #(
        .LOCAL_MAC(LOCAL_MAC),
        .LOCAL_IP(LOCAL_IP),
        .MAX_PAYLOAD_BYTES(64)
    ) dut (
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

    // 125MHz GMII 时钟，周期 8ns。
    initial clk = 1'b0;
    always #4 clk = ~clk;

    // 捕获 DUT 发出的 GMII 字节，后面用 expect_byte 做字段检查。
    always @(posedge clk) begin
        if (gmii_tx_en) begin
            tx_bytes[tx_count] <= gmii_txd;
            tx_count <= tx_count + 1;
        end
    end

    // testbench 用的软件 CRC32，用于给输入帧补正确 FCS。
    function [31:0] crc32_next;
        input [7:0] data;
        input [31:0] crc;
        integer i;
        reg [31:0] c;
        begin
            c = crc ^ {24'd0, data};
            for (i = 0; i < 8; i = i + 1) begin
                if (c[0])
                    c = (c >> 1) ^ 32'hedb88320;
                else
                    c = c >> 1;
            end
            crc32_next = c;
        end
    endfunction

    // 发送一个 GMII 字节；调用者负责决定该字节是否计入 CRC。
    task send_byte;
        input [7:0] b;
        begin
            @(posedge clk);
            gmii_rx_dv <= 1'b1;
            gmii_rxd <= b;
        end
    endtask

    // 发送以太网帧体字节，同时更新输入帧 CRC。
    task send_frame_byte;
        input [7:0] b;
        begin
            send_crc = crc32_next(b, send_crc);
            send_byte(b);
        end
    endtask

    // 构造输入 UDP 帧：HOST -> LOCAL，payload 为 de ad be ef。
    task send_udp_frame;
        reg [15:0] total_len;
        reg [15:0] udp_len;
        begin
            total_len = 16'd32;
            udp_len = 16'd12;
            send_crc = 32'hffff_ffff;

            send_byte(8'h55); send_byte(8'h55); send_byte(8'h55); send_byte(8'h55);
            send_byte(8'h55); send_byte(8'h55); send_byte(8'h55); send_byte(8'hd5);

            send_frame_byte(LOCAL_MAC[47:40]); send_frame_byte(LOCAL_MAC[39:32]);
            send_frame_byte(LOCAL_MAC[31:24]); send_frame_byte(LOCAL_MAC[23:16]);
            send_frame_byte(LOCAL_MAC[15:8]);  send_frame_byte(LOCAL_MAC[7:0]);
            send_frame_byte(HOST_MAC[47:40]);  send_frame_byte(HOST_MAC[39:32]);
            send_frame_byte(HOST_MAC[31:24]);  send_frame_byte(HOST_MAC[23:16]);
            send_frame_byte(HOST_MAC[15:8]);   send_frame_byte(HOST_MAC[7:0]);
            send_frame_byte(8'h08); send_frame_byte(8'h00);

            send_frame_byte(8'h45); send_frame_byte(8'h00);
            send_frame_byte(total_len[15:8]); send_frame_byte(total_len[7:0]);
            send_frame_byte(8'h00); send_frame_byte(8'h00);
            send_frame_byte(8'h40); send_frame_byte(8'h00);
            send_frame_byte(8'h40); send_frame_byte(8'h11);
            send_frame_byte(8'h00); send_frame_byte(8'h00);
            send_frame_byte(HOST_IP[31:24]);  send_frame_byte(HOST_IP[23:16]);
            send_frame_byte(HOST_IP[15:8]);   send_frame_byte(HOST_IP[7:0]);
            send_frame_byte(LOCAL_IP[31:24]); send_frame_byte(LOCAL_IP[23:16]);
            send_frame_byte(LOCAL_IP[15:8]);  send_frame_byte(LOCAL_IP[7:0]);

            send_frame_byte(8'h30); send_frame_byte(8'h39);
            send_frame_byte(8'h04); send_frame_byte(8'hd2);
            send_frame_byte(udp_len[15:8]); send_frame_byte(udp_len[7:0]);
            send_frame_byte(8'h00); send_frame_byte(8'h00);

            send_frame_byte(8'hde);
            send_frame_byte(8'had);
            send_frame_byte(8'hbe);
            send_frame_byte(8'hef);

            send_frame_byte(8'h00); send_frame_byte(8'h00);
            send_frame_byte(8'h00); send_frame_byte(8'h00);
            send_frame_byte(8'h00); send_frame_byte(8'h00);
            send_frame_byte(8'h00); send_frame_byte(8'h00);
            send_frame_byte(8'h00); send_frame_byte(8'h00);
            send_frame_byte(8'h00); send_frame_byte(8'h00);
            send_frame_byte(8'h00); send_frame_byte(8'h00);

            send_crc = ~send_crc;
            send_byte(send_crc[7:0]);
            send_byte(send_crc[15:8]);
            send_byte(send_crc[23:16]);
            send_byte(send_crc[31:24]);

            @(posedge clk);
            gmii_rx_dv <= 1'b0;
            gmii_rxd <= 8'h00;
        end
    endtask

    task send_lldp_like_frame;
        integer i;
        begin
            send_crc = 32'hffff_ffff;

            send_byte(8'h55); send_byte(8'h55); send_byte(8'h55); send_byte(8'h55);
            send_byte(8'h55); send_byte(8'h55); send_byte(8'h55); send_byte(8'hd5);

            send_frame_byte(8'h01); send_frame_byte(8'h80);
            send_frame_byte(8'hc2); send_frame_byte(8'h00);
            send_frame_byte(8'h00); send_frame_byte(8'h0e);
            send_frame_byte(HOST_MAC[47:40]); send_frame_byte(HOST_MAC[39:32]);
            send_frame_byte(HOST_MAC[31:24]); send_frame_byte(HOST_MAC[23:16]);
            send_frame_byte(HOST_MAC[15:8]);  send_frame_byte(HOST_MAC[7:0]);
            send_frame_byte(8'h88); send_frame_byte(8'hcc);

            for (i = 0; i < 46; i = i + 1)
                send_frame_byte(8'h00);

            send_crc = ~send_crc;
            send_byte(send_crc[7:0]);
            send_byte(send_crc[15:8]);
            send_byte(send_crc[23:16]);
            send_byte(send_crc[31:24]);

            @(posedge clk);
            gmii_rx_dv <= 1'b0;
            gmii_rxd <= 8'h00;
        end
    endtask

    // 比较 DUT 输出帧的指定字节，不匹配时立即结束仿真并打印错误。
    task expect_byte;
        input integer index;
        input [7:0] expected;
        begin
            if (tx_bytes[index] !== expected) begin
                $display("FAIL byte[%0d]: expected %02x got %02x", index, expected, tx_bytes[index]);
                $finish;
            end
        end
    endtask

    initial begin
        // 初始化 testbench 信号和记录数组，避免波形里出现无意义的 X。
        rst_n = 1'b0;
        gmii_rx_dv = 1'b0;
        gmii_rxd = 8'h00;
        tx_count = 0;
        send_crc = 32'hffff_ffff;
        for (init_index = 0; init_index < 256; init_index = init_index + 1)
            tx_bytes[init_index] = 8'h00;
        repeat (8) @(posedge clk);
        rst_n = 1'b1;
        repeat (4) @(posedge clk);

        send_lldp_like_frame();
        repeat (12) @(posedge clk);

        send_udp_frame();
        wait(packet_echoed == 1'b1);
        repeat (8) @(posedge clk);

        expect_byte(0, 8'h55);
        expect_byte(7, 8'hd5);
        expect_byte(8, HOST_MAC[47:40]);
        expect_byte(13, HOST_MAC[7:0]);
        expect_byte(14, LOCAL_MAC[47:40]);
        expect_byte(19, LOCAL_MAC[7:0]);
        expect_byte(20, 8'h08);
        expect_byte(21, 8'h00);
        expect_byte(22, 8'h45);
        expect_byte(31, 8'h11);
        expect_byte(34, LOCAL_IP[31:24]);
        expect_byte(37, LOCAL_IP[7:0]);
        expect_byte(38, HOST_IP[31:24]);
        expect_byte(41, HOST_IP[7:0]);
        expect_byte(42, 8'h04);
        expect_byte(43, 8'hd2);
        expect_byte(44, 8'h30);
        expect_byte(45, 8'h39);
        expect_byte(50, 8'hde);
        expect_byte(51, 8'had);
        expect_byte(52, 8'hbe);
        expect_byte(53, 8'hef);

        if (packet_dropped) begin
            $display("FAIL packet_dropped asserted");
            $finish;
        end

        $display("PASS udp_loopback_gmii echoed UDP payload");
        $finish;
    end

    initial begin
        #20000;
        $display("FAIL timeout");
        $finish;
    end

endmodule

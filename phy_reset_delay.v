`timescale 1ns / 1ps

// PHY 上电复位延时模块：
// 复位释放并且时钟稳定后，等待一段时间再拉高 phy_rst_n。
module phy_reset_delay #(
    parameter integer RESET_DELAY_CYCLES = 1000000
)(
    input      clk,
    input      rst_n,
    output reg phy_rst_n,
    output reg ready
);

    localparam [31:0] RESET_DELAY_CYCLES_U = RESET_DELAY_CYCLES;

    reg [31:0] delay_cnt;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            delay_cnt <= 32'd0;
            phy_rst_n <= 1'b0;
            ready <= 1'b0;
        end else if (delay_cnt < RESET_DELAY_CYCLES_U) begin
            delay_cnt <= delay_cnt + 1'b1;
            phy_rst_n <= 1'b0;
            ready <= 1'b0;
        end else begin
            phy_rst_n <= 1'b1;
            ready <= 1'b1;
        end
    end

endmodule

`timescale 1ns / 1ps

// 50MHz -> 200MHz 时钟生成模块：
// 直接例化 Artix-7 MMCME2_BASE 原语，避免使用 Clock Wizard IP 核。
module clk_200m_gen_artix7(
    input  clk_in,
    input  rst_n,
    output clk_200m,
    output locked
);

    wire clkfb;
    wire clkfb_buf;
    wire clkout0;

    MMCME2_BASE #(
        .BANDWIDTH("OPTIMIZED"),
        .CLKIN1_PERIOD(20.000),
        .DIVCLK_DIVIDE(1),
        .CLKFBOUT_MULT_F(20.000),
        .CLKFBOUT_PHASE(0.000),
        .CLKOUT0_DIVIDE_F(5.000),
        .CLKOUT0_DUTY_CYCLE(0.500),
        .CLKOUT0_PHASE(0.000),
        .STARTUP_WAIT("FALSE")
    ) u_mmcm_50m_to_200m (
        .CLKIN1(clk_in),
        .CLKFBIN(clkfb_buf),
        .RST(~rst_n),
        .PWRDWN(1'b0),
        .CLKFBOUT(clkfb),
        .CLKFBOUTB(),
        .CLKOUT0(clkout0),
        .CLKOUT0B(),
        .CLKOUT1(),
        .CLKOUT1B(),
        .CLKOUT2(),
        .CLKOUT2B(),
        .CLKOUT3(),
        .CLKOUT3B(),
        .CLKOUT4(),
        .CLKOUT5(),
        .CLKOUT6(),
        .LOCKED(locked)
    );

    BUFG u_clkfb_bufg (
        .I(clkfb),
        .O(clkfb_buf)
    );

    BUFG u_clkout0_bufg (
        .I(clkout0),
        .O(clk_200m)
    );

endmodule

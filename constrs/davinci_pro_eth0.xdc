## 正点原子达芬奇 Pro - 核心板网口 eth0 约束
## FPGA: Artix-7 XC7A35T/XC7A100T FGG484

## 系统时钟/复位
create_clock -period 20.000 -name sys_clk [get_ports sys_clk]
set_property -dict {PACKAGE_PIN R4 IOSTANDARD LVCMOS15} [get_ports sys_clk]
set_property -dict {PACKAGE_PIN U7 IOSTANDARD LVCMOS15} [get_ports sys_rst_n]

## 核心板网口 eth0 RGMII 接收方向
create_clock -period 8.000 -name eth_rxc [get_ports eth_rxc]
set_property -dict {PACKAGE_PIN U20  IOSTANDARD LVCMOS33} [get_ports eth_rxc]
set_property -dict {PACKAGE_PIN AA20 IOSTANDARD LVCMOS33} [get_ports eth_rx_ctl]
set_property -dict {PACKAGE_PIN AA21 IOSTANDARD LVCMOS33} [get_ports {eth_rxd[0]}]
set_property -dict {PACKAGE_PIN V20  IOSTANDARD LVCMOS33} [get_ports {eth_rxd[1]}]
set_property -dict {PACKAGE_PIN U22  IOSTANDARD LVCMOS33} [get_ports {eth_rxd[2]}]
set_property -dict {PACKAGE_PIN V22  IOSTANDARD LVCMOS33} [get_ports {eth_rxd[3]}]

## 核心板网口 eth0 RGMII 发送方向
set_property -dict {PACKAGE_PIN V18 IOSTANDARD LVCMOS33} [get_ports eth_txc]
set_property -dict {PACKAGE_PIN V19 IOSTANDARD LVCMOS33} [get_ports eth_tx_ctl]
set_property -dict {PACKAGE_PIN T21 IOSTANDARD LVCMOS33} [get_ports {eth_txd[0]}]
set_property -dict {PACKAGE_PIN U21 IOSTANDARD LVCMOS33} [get_ports {eth_txd[1]}]
set_property -dict {PACKAGE_PIN P19 IOSTANDARD LVCMOS33} [get_ports {eth_txd[2]}]
set_property -dict {PACKAGE_PIN R19 IOSTANDARD LVCMOS33} [get_ports {eth_txd[3]}]

## PHY 复位，低有效
set_property -dict {PACKAGE_PIN N20 IOSTANDARD LVCMOS33} [get_ports eth_rst_n]

## 板载 LED0-LED3
set_property -dict {PACKAGE_PIN V9 IOSTANDARD LVCMOS15} [get_ports {led[0]}]
set_property -dict {PACKAGE_PIN Y8 IOSTANDARD LVCMOS15} [get_ports {led[1]}]
set_property -dict {PACKAGE_PIN Y7 IOSTANDARD LVCMOS15} [get_ports {led[2]}]
set_property -dict {PACKAGE_PIN W7 IOSTANDARD LVCMOS15} [get_ports {led[3]}]

## sys_clk 只用于产生 200MHz IDELAY 参考时钟和复位延时。
## eth_rxc 是以太网数据路径时钟，两者按异步时钟处理。
set_false_path -from [get_clocks sys_clk] -to [get_clocks eth_rxc]
set_false_path -from [get_clocks eth_rxc] -to [get_clocks sys_clk]

## 常用 bitstream 配置
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property BITSTREAM.GENERAL.COMPRESS true [current_design]

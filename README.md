# UDP Loopback FPGA Project

这是一个面向 Vivado/Artix-7 的可复用 UDP 通讯工程，当前已在正点原子达芬奇 Pro 核心板网口 GE_0 上完成硬件测试。

工程尽量避免使用 Vivado IP 核。当前通信链路使用 Verilog 代码和 Xilinx 7 Series 原语实现，包含 ARP、UDP 回环、GMII/RGMII 转换和以太网 CRC/FCS 校验。

## 功能

- 以太网帧接收，识别前导码/SFD，剥离 FCS
- Ethernet FCS/CRC32 校验
- ARP request 解析和 ARP reply 自动应答
- IPv4 UDP 接收
- UDP payload 原样回环
- GMII 版本顶层，便于仿真和移植
- Artix-7 RGMII 版本顶层，便于直接连接 PHY
- 正点原子达芬奇 Pro GE_0 板级顶层和约束

当前不实现 ICMP，所以 `ping 192.168.6.12` 不通不代表工程错误。请使用 ARP、Wireshark 或 UDP 调试助手验证。

## 目录结构

```text
udp/
  constrs/
    davinci_pro_eth0.xdc              # 达芬奇 Pro GE_0 管脚约束
  gmii_to_rgmii/
    gmii_to_rgmii_artix7.v            # GMII/RGMII 桥接
    rgmii_rx_artix7.v                 # RGMII 接收，IDELAY + IDDR
    rgmii_tx_artix7.v                 # RGMII 发送，ODDR + TXC 90° 相移
  scripts/
    check_synth.tcl                   # Vivado 综合检查脚本
    fix_vivado_sources.tcl            # 修复 Vivado 工程相对路径
  sim/
    tb_udp_loopback_gmii.v            # GMII 级回环仿真
  udp/
    arp_rx.v                          # ARP 接收解析
    arp_tx.v                          # ARP 应答发送
    eth_crc32_d8.v                    # CRC32 组合逻辑
    eth_frame_rx.v                    # 以太网帧接收和 FCS 校验
    udp_loopback_core.v               # ARP/UDP 回环协议核心
    udp_rx.v                          # UDP 接收解析
    udp_tx.v                          # UDP 回包发送
  clk_200m_gen_artix7.v               # 50MHz -> 200MHz MMCM
  davinci_pro_eth0_udp_loopback_top.v # 达芬奇 Pro GE_0 上板顶层
  phy_reset_delay.v                   # PHY 复位延时
  udp_loopback_gmii.v                 # GMII 仿真/复用顶层
  udp_loopback_rgmii_artix7_top.v     # 通用 Artix-7 RGMII 顶层
  udp.xpr                             # Vivado 工程文件
```

## 顶层模块

### `davinci_pro_eth0_udp_loopback_top`

达芬奇 Pro GE_0 上板顶层。连接板级 `sys_clk/sys_rst_n/eth_*` 管脚，内部完成 200MHz IDELAY 参考时钟生成、PHY 复位延时、RGMII 转换和 UDP 回环。

### `udp_loopback_rgmii_artix7_top`

通用 Artix-7 RGMII 顶层。适合移植到其他使用 RGMII PHY 的 Artix-7 板卡。

### `udp_loopback_gmii`

GMII 版本顶层。适合仿真，或接在已有 MAC/PHY 适配层之后复用。

## 默认网络参数

```text
FPGA IP : 192.168.6.12
FPGA MAC: 00:11:22:33:44:66
```

说明：当前 MAC 已完成直连电脑硬件测试。若后续接入真实局域网，建议把 MAC 改成本地管理单播地址，例如 `02:11:22:33:44:66`，避免使用真实厂商 OUI。

PC 网卡建议设置为：

```text
PC IP : 192.168.6.100
Mask  : 255.255.255.0
Gateway: 留空
```

## 达芬奇 Pro GE_0 管脚

```text
sys_clk      R4
sys_rst_n    U7
eth_rst_n    N20

eth_rxc      U20
eth_rx_ctl   AA20
eth_rxd[0]   AA21
eth_rxd[1]   V20
eth_rxd[2]   U22
eth_rxd[3]   V22

eth_txc      V18
eth_tx_ctl   V19
eth_txd[0]   T21
eth_txd[1]   U21
eth_txd[2]   P19
eth_txd[3]   R19

LED0         V9
LED1         Y8
LED2         Y7
LED3         W7
```

## LED 状态

```text
LED0: PHY 复位释放
LED1: RGMII RX 管脚侧观察到接收活动
LED2: 协议核心收到可处理的 ARP/UDP 包
LED3: 协议核心完成 ARP/UDP 回包发送
```

这些 LED 是长期调试指示，不再是临时 ARP 探针。

## RGMII 时序说明

达芬奇 Pro GE_0 硬件测试中，RGMII 发送方向需要让 `TXC` 相对 `TXD/TX_CTL` 延迟 90°。本工程在 `rgmii_tx_artix7.v` 中使用 `MMCME2_BASE` 生成 90° 相移的发送时钟，使 PHY 在数据眼图中间采样。

已验证链路模式为 1000Mbps，此时 GMII/RGMII 时钟为 125MHz，90° 对应约 2ns。

## Vivado 使用

直接打开：

```text
udp.xpr
```

工程文件使用相对路径，移动或重新克隆工程后仍应可打开。如果 Vivado 源文件路径异常，可在 Tcl Console 执行：

```tcl
source scripts/fix_vivado_sources.tcl
```

命令行综合检查：

```powershell
vivado -mode batch -source scripts/check_synth.tcl
```

## ATK-XNET V1.5 测试

网络调试助手设置：

```text
协议      : UDP
本机 IP   : 192.168.6.100
本机端口  : 12345
目标 IP   : 192.168.6.12
目标端口  : 1234
发送格式  : 十六进制
发送示例  : DE AD BE EF
```

正确现象：

```text
Receive from 192.168.6.12:1234
DE AD BE EF
```

Wireshark 建议过滤：

```text
arp || udp || eth.type == 0x0e06
```

正常情况下可以看到：

```text
192.168.6.12 is at 00:11:22:33:44:66
UDP payload 原样返回
```

不应再出现 `eth.type == 0x0e06` 的错误回包。

## 仿真

GMII testbench 会发送一帧 UDP 数据并检查：

- 源/目的 MAC 交换
- 源/目的 IP 交换
- 源/目的 UDP 端口交换
- payload 原样返回
- 输出以太网 FCS 正确

期望输出：

```text
PASS udp_loopback_gmii echoed UDP payload
```

## 已验证状态

当前版本已完成：

- GMII 级 ModelSim 仿真通过
- Vivado `synth_design` 综合通过
- 达芬奇 Pro GE_0 上板 ARP 应答通过
- ATK-XNET UDP 多次发送/接收回环通过

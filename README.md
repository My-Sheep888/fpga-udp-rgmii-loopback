# UDP Loopback FPGA Project

This project is a reusable Verilog UDP communication module for Vivado. It implements:

- Ethernet frame receive with FCS/CRC check
- ARP request receive and ARP reply transmit
- IPv4 UDP receive and UDP payload loopback
- GMII top-level loopback
- Artix-7 GMII to RGMII bridge using Xilinx primitives

## Directory Layout

```text
udp/
  gmii_to_rgmii/
    gmii_to_rgmii_artix7.v
    rgmii_rx_artix7.v
    rgmii_tx_artix7.v
  udp/
    arp_rx.v
    arp_tx.v
    eth_crc32_d8.v
    eth_frame_rx.v
    udp_loopback_core.v
    udp_rx.v
    udp_tx.v
  sim/
    tb_udp_loopback_gmii.v
  scripts/
    fix_vivado_sources.tcl
  udp_loopback_gmii.v
  udp_loopback_rgmii_artix7_top.v
  udp.xpr
```

Top modules:

- `davinci_pro_eth0_udp_loopback_top`: board top for ALIENTEK Davinci Pro core-board Ethernet port 0.
- `udp_loopback_gmii`: GMII-only UDP loopback top, useful for simulation or reuse behind another MAC/PHY layer.
- `udp_loopback_rgmii_artix7_top`: RGMII board-facing top for Artix-7.

## Vivado Usage

Open `udp.xpr` directly in Vivado. All source paths are relative to the project directory, so the project can be moved or cloned to another path.

If Vivado shows stale source paths after moving files, run this in the Tcl Console:

```tcl
source scripts/fix_vivado_sources.tcl
```

or from a command line:

```powershell
vivado -mode batch -source scripts/fix_vivado_sources.tcl
```

## RGMII Notes

The RGMII bridge uses Xilinx primitives such as `IDDR`, `ODDR`, `IDELAYE2`, `IDELAYCTRL`, `BUFG`, and `BUFIO`. No Vivado IP core is required for the communication logic.

The RGMII receive delay logic requires a 200 MHz reference clock for `IDELAYCTRL`. If the board does not provide a 200 MHz clock, generate one with Vivado Clocking Wizard and connect it to `idelay_clk_200m`.

For the Davinci Pro board top, this project does not use Clocking Wizard. `clk_200m_gen_artix7.v` directly instantiates the Xilinx `MMCME2_BASE` primitive to generate 200 MHz from the 50 MHz `sys_clk`.

## Davinci Pro Hardware Test

The hardware top `davinci_pro_eth0_udp_loopback_top` is wired for the core-board Ethernet port 0:

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
```

Default FPGA network parameters:

```text
FPGA IP:  192.168.6.12
FPGA MAC: 00:11:22:33:44:66
```

Set the PC Ethernet adapter to:

```text
PC IP:  192.168.6.100
Mask:   255.255.255.0
Gateway: empty
```

ATK-XNET V1.5 test settings:

```text
Protocol: UDP
Remote IP: 192.168.6.12
Remote port: 1234
Local port: 12345
Payload example: DE AD BE EF
```

This project implements ARP and UDP loopback, but not ICMP. A failed `ping` does not necessarily mean the FPGA design is wrong. Use Wireshark or ATK-XNET UDP receive data to confirm the test.

## Simulation

The GMII testbench sends one UDP packet to the local MAC/IP and checks that the design returns a UDP packet with:

- source and destination MAC addresses swapped
- source and destination IP addresses swapped
- source and destination UDP ports swapped
- payload returned unchanged
- valid Ethernet FCS

Expected simulation message:

```text
PASS udp_loopback_gmii echoed UDP payload
```

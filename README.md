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

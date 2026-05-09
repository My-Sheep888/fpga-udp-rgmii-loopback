if {[catch {current_project}]} {
  set script_dir [file dirname [file normalize [info script]]]
  open_project [file normalize [file join $script_dir .. udp.xpr]]
}

set project_dir [get_property DIRECTORY [current_project]]

set rtl_files [list \
  [file join $project_dir udp arp_rx.v] \
  [file join $project_dir udp arp_tx.v] \
  [file join $project_dir udp eth_frame_rx.v] \
  [file join $project_dir gmii_to_rgmii gmii_to_rgmii_artix7.v] \
  [file join $project_dir gmii_to_rgmii rgmii_rx_artix7.v] \
  [file join $project_dir gmii_to_rgmii rgmii_tx_artix7.v] \
  [file join $project_dir udp udp_loopback_core.v] \
  [file join $project_dir udp udp_rx.v] \
  [file join $project_dir udp udp_tx.v] \
  [file join $project_dir udp_loopback_rgmii_artix7_top.v] \
  [file join $project_dir udp eth_crc32_d8.v] \
  [file join $project_dir udp_loopback_gmii.v] \
]

set sim_file [file join $project_dir sim tb_udp_loopback_gmii.v]

remove_files -quiet [get_files -quiet */rtl/*]
remove_files -quiet [get_files -quiet *tb_udp_loopback_gmii.v]

add_files -fileset sources_1 -norecurse $rtl_files
add_files -fileset sim_1 -norecurse $sim_file

set sim_files [get_files -quiet $sim_file]
if {[llength $sim_files] > 0} {
  set_property USED_IN_SYNTHESIS false $sim_files
  set_property USED_IN_IMPLEMENTATION false $sim_files
  set_property USED_IN_SIMULATION true $sim_files
}

set_property top udp_loopback_rgmii_artix7_top [get_filesets sources_1]
set_property top tb_udp_loopback_gmii [get_filesets sim_1]

update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

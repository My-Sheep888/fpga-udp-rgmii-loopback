if {[catch {current_project}]} {
  set script_dir [file dirname [file normalize [info script]]]
  open_project [file normalize [file join $script_dir .. udp.xpr]]
}

set top_name davinci_pro_eth0_udp_loopback_top
set part_name [get_property PART [current_project]]

update_compile_order -fileset sources_1
synth_design -top $top_name -part $part_name
report_utilization

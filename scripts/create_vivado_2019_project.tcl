set script_dir [file normalize [file dirname [info script]]]
set origin_dir [file normalize [file join $script_dir ".."]]
set usage_message "Usage: vivado -mode batch -source scripts/create_vivado_2019_1_project.tcl -tclargs ?part? ?project_name? ?project_dir? ?board_part?"
set default_part "xc7a35tcpg236-1"
set default_project_name "vga_pattern_generator"

if {![string match "2019.1*" [version -short]]} {
  puts "INFO: this script was prepared for Vivado 2019.1, current version is [version -short]."
}

if {[llength $argv] > 0} {
  set first_arg [lindex $argv 0]
  if {($first_arg eq "-h") || ($first_arg eq "--help") || ($first_arg eq "help")} {
    puts $usage_message
    puts "INFO: default part = $default_part"
    return
  }
}

if {[llength $argv] >= 1} {
  set target_part [lindex $argv 0]
} elseif {[info exists ::env(VIVADO_TARGET_PART)] && ($::env(VIVADO_TARGET_PART) ne "")} {
  set target_part $::env(VIVADO_TARGET_PART)
} elseif {[info exists ::env(TARGET_PART)] && ($::env(TARGET_PART) ne "")} {
  set target_part $::env(TARGET_PART)
} elseif {[info exists ::env(FPGA_PART)] && ($::env(FPGA_PART) ne "")} {
  set target_part $::env(FPGA_PART)
} else {
  set target_part $default_part
}

set project_name [expr {[llength $argv] >= 2 ? [lindex $argv 1] : $default_project_name}]
set project_dir [expr {[llength $argv] >= 3 ? [file normalize [lindex $argv 2]] : [file normalize [file join $origin_dir "vivado" $project_name]]}]

if {[llength $argv] >= 4} {
  set board_part [lindex $argv 3]
} elseif {[info exists ::env(VIVADO_BOARD_PART)] && ($::env(VIVADO_BOARD_PART) ne "")} {
  set board_part $::env(VIVADO_BOARD_PART)
} else {
  set board_part ""
}

create_project $project_name -force $project_dir -part $target_part
set_property target_language Verilog [current_project]
set_property simulator_language Mixed [current_project]

if {$board_part ne ""} {
  set matching_board_parts [get_board_parts -quiet $board_part]
  if {[llength $matching_board_parts] > 0} {
    set_property board_part [lindex $matching_board_parts 0] [current_project]
  } else {
    puts "WARNING: board_part '$board_part' not found in the current Vivado board repositories; continuing with target part only."
    set board_part ""
  }
}

set rtl_files [list \
  [file join $origin_dir rtl video_types_pkg.sv] \
  [file join $origin_dir rtl axis_skid_buffer.sv] \
  [file join $origin_dir rtl video_rate_gen.sv] \
  [file join $origin_dir rtl pattern_generator_axis.sv] \
  [file join $origin_dir rtl axis_to_vga.sv] \
  [file join $origin_dir rtl video_pipeline_top.sv] \
]

set tb_files [list \
  [file join $origin_dir tb video_pipeline_if.sv] \
  [file join $origin_dir tb video_pipeline_tb_pkg.sv] \
  [file join $origin_dir tb video_pipeline_tb.sv] \
  [file join $origin_dir tb video_pipeline_timing.wcfg] \
]

set constraint_files [glob -nocomplain [file join $origin_dir constraints *.xdc]]

foreach rtl_file $rtl_files {
  add_files -norecurse $rtl_file
}

if {[llength $constraint_files] > 0} {
  foreach constraint_file $constraint_files {
    add_files -fileset constrs_1 -norecurse $constraint_file
  }
  set_property target_constrs_file [lindex $constraint_files 0] [current_fileset -constrset]
}

foreach tb_file $tb_files {
  add_files -fileset sim_1 -norecurse $tb_file
}

set_property top video_pipeline_top [get_filesets sources_1]
set_property top video_pipeline_tb [get_filesets sim_1]
set_property SOURCE_SET sources_1 [get_filesets sim_1]
set_property xsim.simulate.runtime 250ms [get_filesets sim_1]

update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

puts "INFO: project created at $project_dir"
puts "INFO: target_part = $target_part"
puts "INFO: synthesis top = video_pipeline_top"
puts "INFO: simulation top = video_pipeline_tb"
if {$board_part ne ""} {
  puts "INFO: board_part = $board_part"
}
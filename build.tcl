load_package flow

set project [lindex $argv 0]
set top     [lindex $argv 1]
set srcs    [lindex $argv 2]
set qips    [lindex $argv 3]
set sdc     [lindex $argv 4]

project_new $project -overwrite

set_global_assignment -name FAMILY "Cyclone IV E"
set_global_assignment -name DEVICE EP4CE22F17C6
set_global_assignment -name TOP_LEVEL_ENTITY $top
set_global_assignment -name NUM_PARALLEL_PROCESSORS ALL

set csv_file "pins.csv"
if {[file exists $csv_file]} {
    set f [open $csv_file r]
    gets $f header
    while {[gets $f line] >= 0} {
        set fields [split $line ","]
        set node [string trim [lindex $fields 0]]
        set pin  [string trim [lindex $fields 1]]
        set std  [string trim [lindex $fields 2]]
        if {$node != "" && $pin != ""} {
            set_location_assignment $pin -to $node
            if {$std != ""} {
                set_instance_assignment -name IO_STANDARD $std -to $node
            }
        }
    }
    close $f
}

foreach src [split $srcs] {
    if {$src != ""} {
        set_global_assignment -name SYSTEMVERILOG_FILE $src
    }
}

foreach qip [split $qips] {
    if {$qip != ""} {
        set_global_assignment -name QIP_FILE $qip
    }
}

if {[file exists $sdc]} {
    set_global_assignment -name SDC_FILE $sdc
}

execute_flow -compile

project_close

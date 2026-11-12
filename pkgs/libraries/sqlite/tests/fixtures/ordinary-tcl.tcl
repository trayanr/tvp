set root [lindex $argv 0]
set candidates [exec find $root/lib -type f -name pkgIndex.tcl]
set selected 0
foreach index [split $candidates \n] {
    set dir [file dirname $index]
    source $index
    foreach version [package versions sqlite3] {
        set script [package ifneeded sqlite3 $version]
        if {[string first $root $script] >= 0} {
            eval $script
            set selected 1
            break
        }
    }
    if {$selected} break
}
if {!$selected} {error "no owned SQLite Tcl package"}
sqlite3 db :memory:
puts [db eval {select 'tvp'}]
db close

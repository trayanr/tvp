set prefix [lindex $argv 0]
set mode [lindex $argv 1]
if {[info patchlevel] ne "8.6.18"} {error "wrong Tcl ABI"}
if {$mode eq "negative"} {
    if {![catch {package require -exact sqlite3 3.53.4}]} {error "ambient standalone discovery"}
    package require -exact sqlite3 3.53.0
    set expected [file join [file dirname [file dirname [info nameofexecutable]]] lib sqlite3.53.0 libsqlite3.53.0.so]
} else {
    if {$mode eq "explicit"} {
        load [file join $prefix lib tcl libsqlite3.53.4.so] Sqlite3
    } else {
        lappend auto_path [file join $prefix lib tcl]
    }
    package require -exact sqlite3 3.53.4
    set expected [file join $prefix lib tcl libsqlite3.53.4.so]
}
set loaded [lindex [lindex [info loaded] 0] 0]
puts stderr "loaded $loaded"
if {[file normalize $loaded] ne [file normalize $expected]} {error "wrong DSO: $loaded expected $expected"}
sqlite3 db data.db
db eval {create table t(a); begin; insert into t values(42); commit;}
if {[db onecolumn {select a from t}] != 42} {error "database contract"}
db close
sqlite3 db data.db
if {[db onecolumn {select a from t}] != 42} {error "persistence contract"}
set version [db onecolumn {select sqlite_version()}]
db close
if {$mode eq "negative"} {puts "bundled $version retained"} else {puts "tcl [info patchlevel] sqlite $version"}

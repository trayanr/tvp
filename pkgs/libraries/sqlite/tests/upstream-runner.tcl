# The upstream workload and native counters are unchanged. Invoked by the
# privately built fixture; final installed CLI reconciliation belongs to U.
set version [lindex $argv 0]
if {[package require -exact sqlite3 $version] ne $version} {error "wrong runner SQLite"}
set argv0 test/testrunner.tcl
set argv [list --jobs 8 veryquick]
source $argv0
sqlite3 results testrunner.db
set jobs [results onecolumn {select count(*) from jobs}]
set cases [results onecolumn {select sum(ntest) from jobs}]
set errors [results onecolumn {select sum(nerr) from jobs}]
set unfinished [results onecolumn {select count(*) from jobs where state!='done' or ntest is null or nerr is null}]
puts "upstream veryquick jobs=$jobs cases=$cases errors=$errors unfinished=$unfinished"
if {$jobs<1 || $cases<1 || $errors!=0 || $unfinished!=0} {exit 1}

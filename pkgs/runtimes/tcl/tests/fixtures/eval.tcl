set n 0
for {set i 1} {$i <= 6} {incr i} { set n [expr {$n + $i}] }
set name [string tolower "TVP"]
set items [list a b c]
puts "[expr {$n * 2}] $name [llength $items]"

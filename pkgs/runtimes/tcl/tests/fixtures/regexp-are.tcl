set text "north star: tvp preserves"
if {[regexp {star:\s+(\w+)} $text -> word]} { puts $word } else { puts NOMATCH }

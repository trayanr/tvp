set text "north star: tvp preserves"
if {[regexp {star: ([a-z]+)} $text -> word]} { puts $word } else { puts NOMATCH }

{ package }:
let
  d = package.tvp.deps;
in
import ../../../../lib/tests/recorded.nix {
  inherit package;
  name = "debugger-line-edit";
  tools = package.specification.environment.tools ++ [ d.python ];
  script = ''
    mkdir "$out"
    unset COLUMNS LINES TERMINFO TERMINFO_DIRS
    export TERM=xterm TERMINFO=${d.ncurses}/share/terminfo TERMINFO_DIRS=${d.ncurses}/share/terminfo
    probe=0
    ${d.python}/bin/python3 ${../../../libraries/readline/tests/pty.py} --probe || probe=$?
    if test "$probe" = 77; then
      echo 'SKIP: independent PTY capability probe' | tee "$out/status"
      exit 0
    fi
    test "$probe" = 0
    ${d.python}/bin/python3 ${../../../libraries/readline/tests/pty.py} --gawk ${package}/bin/gawk > "$out/log" 2>&1
    echo PASS > "$out/status"
  '';
}

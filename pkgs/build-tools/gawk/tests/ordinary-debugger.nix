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
    ${d.python}/bin/python3 ${./ordinary-pty.py} --probe || probe=$?
    if test "$probe" = 77; then
      echo 'SKIP: independent PTY capability probe' | tee "$out/status"
      exit 0
    fi
    test "$probe" = 0
    ${d.python}/bin/python3 ${./ordinary-pty.py} ${
      if package.tvp.readlineProgram == "dgawk" then "--dgawk" else "--gawk"
    } ${package}/bin/${package.tvp.readlineProgram} > "$out/log" 2>&1 || { result=$?; cat "$out/log" >&2; exit "$result"; }
    echo PASS > "$out/status"
  '';
}

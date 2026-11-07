{ package }:
let
  d = package.tvp.deps;
in
import ../../../../lib/tests/recorded.nix {
  inherit package;
  name = "line-edit-history";
  tools = package.specification.environment.tools ++ [ d.python ];
  libraries = [ package ];
  script = ''
    mkdir "$out"
    unset COLUMNS LINES TERMINFO TERMINFO_DIRS
    export TERM=xterm TERMINFO=${d.ncurses}/share/terminfo TERMINFO_DIRS=${d.ncurses}/share/terminfo
    probe=0
    ${d.python}/bin/python3 ${./pty.py} --probe || probe=$?
    if test "$probe" = 77; then
      echo 'SKIP: independent PTY capability probe' | tee "$out/status"
      exit 0
    fi
    test "$probe" = 0
    cc -I${package}/include ${./fixtures/line-edit.c} ${package}/lib/libreadline.so -Wl,-rpath,${package}/lib -o line-edit
    ${d.python}/bin/python3 ${./pty.py} --readline "$PWD/line-edit" > "$out/log" 2>&1
    echo PASS > "$out/status"
  '';
}

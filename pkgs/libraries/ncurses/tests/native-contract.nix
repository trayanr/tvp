{ package }:
let d = package.tvp.deps; in
package.testContext.mkSuite {
  inherit package;
  tools = package.specification.environment.tools ++ [ d.binutils d.patchelf ];
  libraries = [ package ];
  tests = {
    database-roundtrip = {
      script = ''
        unset COLUMNS LINES TERMINFO TERMINFO_DIRS
        export TERMINFO=${package}/share/terminfo TERMINFO_DIRS=${package}/share/terminfo
        ${package}/bin/infocmp -1 xterm > original
        mkdir private
        ${package}/bin/tic -x -o "$PWD/private" original
        TERMINFO="$PWD/private" TERMINFO_DIRS="$PWD/private" ${package}/bin/infocmp -1 xterm > roundtrip
        # The first comment names the source database, not terminal capabilities.
        sed '1d' original > a; sed '1d' roundtrip > b; cmp a b
        test "$(TERMINFO="$PWD/private" TERMINFO_DIRS="$PWD/private" TERM=xterm ${package}/bin/tput cols)" = 80
        echo roundtrip
      '';
      expected = "roundtrip";
    };
    static-layout = {
      script = ''
        export PKG_CONFIG_LIBDIR=${package}/lib/pkgconfig
        for module in ncursesw formw menuw panelw ncurses++w; do
          test -s ${package}/lib/lib$module.a
          test "$(pkg-config --modversion "$module" | cut -d. -f1,2)" = ${package.version}
          pkg-config --static --libs "$module" > flags
          if grep -- '-ltinfo' flags; then exit 1; fi
        done
        test ! -e ${package}/lib/libncurses++w.so
        test ! -e ${package}/lib/libtinfo.so
        cc ${./fixtures/terminfo.c} ${package}/lib/libncursesw.a -o static-terminfo
        unset COLUMNS LINES
        export TERMINFO=${package}/share/terminfo TERMINFO_DIRS=${package}/share/terminfo
        test "$(./static-terminfo)" = 80
        LD_TRACE_LOADED_OBJECTS=1 ${package}/bin/tput > loaded
        grep -F '${package}/lib/libncursesw.so.6' loaded >/dev/null
        echo wide-static-and-shared
      '';
      expected = "wide-static-and-shared";
    };
  };
}

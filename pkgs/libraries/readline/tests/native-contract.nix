{ package }:
let d = package.tvp.deps; in
package.testContext.mkSuite {
  inherit package;
  tools = package.specification.environment.tools ++ [ d.binutils ];
  tests.public-private-contract = {
    script = ''
      cc -I${package}/include ${./fixtures/history.c} ${package}/lib/libhistory.so -Wl,-rpath,${package}/lib -o history
      test "$(./history)" = '2 tvp'
      export PKG_CONFIG_LIBDIR=${package}/lib/pkgconfig:${d.ncurses}/lib/pkgconfig
      for module in readline history; do
        test "$(pkg-config --modversion "$module")" = ${package.version}
        pkg-config --libs "$module" >&2
        pkg-config --static --libs "$module" >&2
      done
      test -z "$(find ${package}/lib -name '*.a' -print)"
      readelf -d ${package}/lib/libreadline.so > dynamic
      grep -F 'Shared library: [libncursesw.so.6]' dynamic >/dev/null
      if grep -E 'NEEDED.*libtinfo' dynamic; then exit 1; fi
      echo shared-public-headers-private-curses
    '';
    expected = "shared-public-headers-private-curses";
  };
}

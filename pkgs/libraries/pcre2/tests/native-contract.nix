{ package }:
let d = package.tvp.deps; in
package.testContext.mkSuite {
  inherit package;
  tools = package.specification.environment.tools ++ [ d.binutils ];
  tests.pkgconfig = {
    script = ''
      export PKG_CONFIG_LIBDIR=${package}/lib/pkgconfig
      for module in libpcre2-8 libpcre2-16 libpcre2-32 libpcre2-posix; do
        test "$(pkg-config --modversion "$module")" = ${package.version}
        pkg-config --cflags --libs "$module" >&2
      done
      test "$(${package}/bin/pcre2-config --version)" = ${package.version}
      test -z "$(find ${package}/lib -name '*.a' -print)"
      echo shared-only-four-modules
    '';
    expected = "shared-only-four-modules";
  };
}

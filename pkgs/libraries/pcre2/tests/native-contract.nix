{ lib, package }:
let
  d = package.tvp.deps;
in
package.testContext.mkSuite {
  inherit package;
  tools = package.specification.environment.tools ++ [ d.binutils ];
  tests =
    {
      pkgconfig = {
        script = ''
          export PKG_CONFIG_LIBDIR=${package}/lib/pkgconfig
          for module in libpcre2-8 libpcre2-16 libpcre2-32 libpcre2-posix; do
            test "$(pkg-config --modversion "$module")" = ${package.version}
            pkg-config --cflags --libs "$module" >&2
          done
          test "$(${package}/bin/pcre2-config --version)" = ${package.version}
          echo four-modules
        '';
        expected = "four-modules";
      };
    }
    // lib.optionalAttrs (!package.tvp.features.static) {
      shared-layout = {
        script = ''
          test -z "$(find ${package}/lib -name '*.a' -print)"
          echo shared-only
        '';
        expected = "shared-only";
      };
    }
    // lib.optionalAttrs package.tvp.features.static {
      static-layout = {
        script = ''
          for module in 8 16 32 posix; do
            archive=${package}/lib/libpcre2-$module.a
            test -s "$archive"
            ${d.binutils}/bin/ar t "$archive" > members
            test -s members
          done
          echo four-static-archives
        '';
        expected = "four-static-archives";
      };
    };
}

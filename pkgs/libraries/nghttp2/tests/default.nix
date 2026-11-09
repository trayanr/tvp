{
  pkgs,
  tvpLib,
  package,
}:
let
  mkSuite =
    if package ? testContext then
      args:
      package.testContext.mkSuite {
        package = package;
        libraries = [ package ];
        tests = builtins.mapAttrs (_: spec: {
          inherit (spec) script expected;
          tools = (spec.extraInputs or [ ]) ++ [ package.tvp.deps.grep ];
        }) args.tests;
      }
    else
      tvpLib.tests.mkSuite;
in
mkSuite {
  inherit pkgs package;
  tests = {
    hpack = {
      script = "cc -I${package}/include ${./fixtures/hpack.c} -L${package}/lib -lnghttp2 -o hpack; ./hpack";
      expected = package.version;
      extraInputs = [ package.tvp.cc ];
    };
  }
  // pkgs.lib.optionalAttrs (package ? testContext) {
    installed-provider = {
      script = ''
        set -euo pipefail
        export PKG_CONFIG_LIBDIR=${package}/lib/pkgconfig
        test "$(pkg-config --modversion libnghttp2)" = ${pkgs.lib.escapeShellArg package.version}
        flags=$(pkg-config --cflags --libs libnghttp2)
        cc -Wall -Wextra -Werror ${./fixtures/hpack.c} $flags -o shared
        cc -Wall -Wextra -Werror -I${package}/include ${./fixtures/hpack.c} ${package}/lib/libnghttp2.a -o archive
        test "$(env -i ./shared)" = ${pkgs.lib.escapeShellArg package.version}
        test "$(env -i ./archive)" = ${pkgs.lib.escapeShellArg package.version}
        env -i LD_DEBUG=libs ./shared > /dev/null 2> loader
        grep -F 'calling init: ${package}/lib/libnghttp2.so.14' loader >&2
        test -z "$(ls -A ${package}/bin)"
        echo ok
      '';
      expected = "ok";
      extraInputs = [
        package.tvp.cc
        package.tvp.deps.pkg-config
      ];
    };
  };
}

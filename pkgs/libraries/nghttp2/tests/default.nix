{
  package,
  lib,
  context,
}:

let
  mkSuite =
    args:
    context.mkSuite {
      inherit package;
      libraries = [ package ];
      tests = builtins.mapAttrs (
        _: test:
        (builtins.removeAttrs test [ "extraInputs" ])
        // {
          tools =
            (test.tools or [ ])
            ++ (test.extraInputs or [ ])
            ++ [
              package.specification.gawk or package.specification.base.standardTools.gawk
              package.specification.grep or package.specification.base.standardTools.grep
              package.specification.sed or package.specification.base.standardTools.sed
            ];
        }
      ) args.tests;
    };
in
mkSuite {
  inherit package;
  tests =
    {
      hpack = {
        script = "cc -I${package}/include ${./fixtures/hpack.c} -L${package}/lib -lnghttp2 -o hpack; ./hpack";
        expected = package.version;
        extraInputs = [ package.tvp.cc ];
      };
    }
    // lib.optionalAttrs (package ? testContext) {
      installed-provider = {
        script = ''
          set -euo pipefail
          export PKG_CONFIG_LIBDIR=${package}/lib/pkgconfig
          test "$(pkg-config --modversion libnghttp2)" = ${lib.escapeShellArg package.version}
          flags=$(pkg-config --cflags --libs libnghttp2)
          cc -Wall -Wextra -Werror ${./fixtures/hpack.c} $flags -o shared
          cc -Wall -Wextra -Werror -I${package}/include ${./fixtures/hpack.c} ${package}/lib/libnghttp2.a -o archive
          test "$(env -i ./shared)" = ${lib.escapeShellArg package.version}
          test "$(env -i ./archive)" = ${lib.escapeShellArg package.version}
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

// lib.optionalAttrs (package.specification.upstreamCheck.enabled or false) {
  upstream = context.mkUpstream { inherit package; };
}

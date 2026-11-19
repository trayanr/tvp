{
  package,
  lib,
  context,
}:
let
  zstd = package;
  gzip = package.tvp.declaredTestDependencies.gzip;
in

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
              package.specification.gawk or package.specification.base.tools.gawk
              package.specification.grep or package.specification.base.tools.grep
              package.specification.sed or package.specification.base.tools.sed
            ];
        }
      ) args.tests;
    };
  cc = [ zstd.tvp.cc ];
in
mkSuite {

  package = zstd;
  tests = {
    version = {
      script = ''
        cc ${./fixtures/version.c} -lzstd -o version
        ./version
      '';
      expected = zstd.version;
      extraInputs = cc;
    };
    compress = {
      script = ''
        cc ${./fixtures/roundtrip.c} -lzstd -o roundtrip
        ./roundtrip
      '';
      expected = "tvp preserved";
      extraInputs = cc;
    };
    static = {
      script = ''
        cc ${./fixtures/roundtrip.c} ${zstd}/lib/libzstd.a -pthread -o roundtrip
        ./roundtrip
      '';
      expected = "tvp preserved";
      extraInputs = cc;
    };
    cli = {
      script = "printf 'tvp' | zstd -q -c | zstd -q -d -c";
      expected = "tvp";
    };
    gzip = {
      script = "printf 'tvp' | zstd --format=gzip -q -c | ${gzip}/bin/gzip -dc";
      expected = "tvp";
    };
    xz = {
      script = "printf 'tvp' | zstd --format=xz -q -c | ${zstd.tvp.deps.xz}/bin/xz -dc";
      expected = "tvp";
    };
  }
  // lib.optionalAttrs (zstd ? testContext) {
    installed-layout = {
      script = ''
        set -euo pipefail
        for alias in unzstd zstdcat zstdmt; do
          test "$(readlink ${zstd}/bin/$alias)" = zstd
        done
        for name in zstd zstdgrep zstdless unzstd zstdcat; do
          ${gzip}/bin/gzip -t ${zstd}/share/man/man1/$name.1.gz
          test ! -e ${zstd}/share/man/man1/$name.1
        done
        echo ok
      '';
      expected = "ok";
    };
  };
}

// lib.optionalAttrs (package.specification.upstreamCheck.enabled or false) {
  upstream = context.mkUpstream { inherit package; };
}

// {
  helpers = import ./current-helpers.nix { inherit package lib context; };
}
// lib.optionalAttrs (package.version == "1.5.6") (
  import ./current-contracts.nix { inherit package lib context; }
)

// lib.optionalAttrs ((package.tvp.variant or null) == "build-steps") {
  runtime-expectation = import ../../../../lib/runtime-expectation.nix { inherit lib; } {
    inherit package context;
    python = package.tvp.declaredTestDependencies.python;
  };
}

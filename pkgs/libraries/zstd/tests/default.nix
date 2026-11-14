{
  pkgs,
  tvpLib,
  zstd,
  gzip,
}:
let
  mkSuite =
    if zstd ? testContext then
      args:
      zstd.testContext.mkSuite {
        package = zstd;
        libraries = [ zstd ];
        tests = builtins.mapAttrs (_: spec: {
          inherit (spec) script expected;
          tools = (spec.extraInputs or [ ]) ++ [ zstd.tvp.deps.gnugrep ];
        }) args.tests;
      }
    else
      tvpLib.tests.mkSuite;
  cc = [ zstd.tvp.cc ];
in
mkSuite {
  inherit pkgs;
  package = zstd;
  tests =
    {
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
    // pkgs.lib.optionalAttrs (zstd ? testContext) {
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

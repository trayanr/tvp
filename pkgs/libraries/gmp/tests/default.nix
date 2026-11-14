# One installed suite for every GMP era; upstream acceptance is independent A/F.
{
  package,
  lib,
  context,
}:
(context.mkSuite {
  inherit package;
  libraries = [ package ];
  tests =
    {
      version = {
        script = ''"$CC" ${./fixtures/version.c} -lgmp -o version; ./version'';
        expected = package.tvp.reportedVersion;
      };
      arithmetic = {
        script = ''"$CC" ${./fixtures/arithmetic.c} -lgmp -o arithmetic; ./arithmetic'';
        expected = "340282366920938463463374607431768211456";
      };
    }
    // lib.optionalAttrs package.tvp.features.cxx {
      cxx = {
        script = ''"$CXX" ${./fixtures/cxx.cc} -lgmpxx -lgmp -o cxx; ./cxx'';
        expected = "42";
      };
    };
})
// lib.optionalAttrs (package.specification.upstreamCheck.enabled or true) {
  upstream = import ./upstream.nix { inherit package; };
}

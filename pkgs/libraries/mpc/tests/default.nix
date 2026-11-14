# Installed assertions are declared once for every supported MPC release.
{
  package,
  lib,
  context,
}:
(context.mkSuite {
  inherit package;
  libraries = [ package ];
  tests = {
    version = {
      script = ''"$CC" ${./fixtures/version.c} -lmpc -lmpfr -lgmp -o version; ./version'';
      expected = package.version;
    };
    arithmetic = {
      script = ''"$CC" ${./fixtures/arithmetic.c} -lmpc -lmpfr -lgmp -o arithmetic; ./arithmetic'';
      expected = "25";
    };
  };
})
// lib.optionalAttrs (package.specification.upstreamCheck.enabled or true) {
  upstream = context.mkUpstream { inherit package; };
}

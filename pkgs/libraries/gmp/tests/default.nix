{
  pkgs,
  tvpLib,
  gmp,
}:
tvpLib.tests.mkSuite {
  inherit pkgs;
  package = gmp;
  tests =
    {
      version = {
        script = ''cc ${./fixtures/version.c} -lgmp -o version; ./version'';
        expected = gmp.tvp.reportedVersion;
        extraInputs = [ gmp.tvp.cc ];
      };
      arithmetic = {
        script = ''cc ${./fixtures/arithmetic.c} -lgmp -o arithmetic; ./arithmetic'';
        expected = "340282366920938463463374607431768211456";
        extraInputs = [ gmp.tvp.cc ];
      };
    }
    // pkgs.lib.optionalAttrs gmp.tvp.features.cxx {
      cxx = {
        script = ''c++ ${./fixtures/cxx.cc} -lgmpxx -lgmp -o cxx; ./cxx'';
        expected = "42";
        extraInputs = [ gmp.tvp.cc ];
      };
    };
}

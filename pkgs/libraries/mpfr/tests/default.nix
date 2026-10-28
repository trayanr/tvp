{
  pkgs,
  tvpLib,
  mpfr,
}:
tvpLib.tests.mkSuite {
  inherit pkgs;
  package = mpfr;
  tests =
    {
      version = {
        script = ''cc ${./fixtures/version.c} -lmpfr -lgmp -o version; ./version'';
        expected = mpfr.version;
        extraInputs = [ mpfr.tvp.cc ];
      };
      legacy-arithmetic = {
        script = ''cc ${./fixtures/legacy-arithmetic.c} -lmpfr -lgmp -o arithmetic; ./arithmetic'';
        expected = "12";
        extraInputs = [ mpfr.tvp.cc ];
      };
    }
    // pkgs.lib.optionalAttrs mpfr.tvp.features.mpfrRoundingNames {
      arithmetic = {
        script = ''cc ${./fixtures/arithmetic.c} -lmpfr -lgmp -o arithmetic; ./arithmetic'';
        expected = "12";
        extraInputs = [ mpfr.tvp.cc ];
      };

    }
    // pkgs.lib.optionalAttrs mpfr.tvp.features.float128 {
      float128 = {
        script = ''
          cc ${./fixtures/float128.c} -lmpfr -lgmp -lquadmath -o float128
          ./float128
        '';
        expected = "42";
        extraInputs = [ mpfr.tvp.cc ];
      };
    };
}

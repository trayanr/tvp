# The ordinary suite is declared once and instantiated for every MPFR release.
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
        script = ''"$CC" ${./fixtures/version.c} -lmpfr -lgmp -o version; ./version'';
        expected = package.version;
      };
      legacy-arithmetic = {
        script = ''"$CC" ${./fixtures/legacy-arithmetic.c} -lmpfr -lgmp -o arithmetic; ./arithmetic'';
        expected = "12";
      };
    }
    // lib.optionalAttrs package.tvp.features.mpfrRoundingNames {
      arithmetic = {
        script = ''"$CC" ${./fixtures/arithmetic.c} -lmpfr -lgmp -o arithmetic; ./arithmetic'';
        expected = "12";
      };
    }
    // lib.optionalAttrs package.tvp.features.float128 {
      float128 = {
        script = ''"$CC" ${./fixtures/float128.c} -lmpfr -lgmp -lquadmath -o float128; ./float128'';
        expected = "42";
      };
    };
})
//
  lib.optionalAttrs
    (package.specification ? upstreamCheck && (package.specification.upstreamCheck.enabled or true))
    {
      upstream = import ../../acl/native/upstream.nix { inherit package; };
    }

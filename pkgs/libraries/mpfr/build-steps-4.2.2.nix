# Modern MPFR only. Source/features match the canonical 4.2.2 control.
{
  lib,
  base,
  src,
  version,
  gmp,
  bash,
  coreutils,
  gnumake,
  gnutar,
  xz,
  doCheck ? true,
}:
let
  helpers = import ../../../lib/native-steps.nix { inherit lib; };
in
{
  pname = "mpfr";
  inherit
    base
    src
    version
    bash
    coreutils
    ;
  plan =
    helpers.unpack {
      inherit src xz;
      tar = gnutar;
    }
    ++ helpers.autotools {
      name = "mpfr";
      make = gnumake;
      libraries = [ gmp ];
      configureFlags = [ "--with-gmp=${lib.getDev gmp}" ];
      inherit doCheck;
    }
    ++ helpers.finalize { propagatedLibraries = [ gmp ]; };
  runtime.libraries = [ (lib.getLib gmp) ];
  tvp.features = {
    float128 = true;
    mpfrRoundingNames = true;
  };
  meta = {
    description = "Correctly rounded multiple-precision floating-point arithmetic";
    license = lib.licenses.lgpl3Plus;
    platforms = [ "x86_64-linux" ];
  };
}

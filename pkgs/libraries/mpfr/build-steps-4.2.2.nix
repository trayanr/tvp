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
  python,
  binutils,
  patchelf,
  stripFlags ? [
    "-S"
    "-p"
  ],
  dlopenDirectories ? [ ],
  doCheck ? true,
}:
let
  helpers = import ../../../lib/native-steps.nix { inherit lib; };
  output = import ../../../lib/native-output-steps.nix { inherit lib; };
  elfPaths = [ "lib/libmpfr.so.6.2.2" ];
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
      configureFlags = [
        "--disable-static"
        "--disable-dependency-tracking"
        "--with-gmp=${lib.getDev gmp}"
      ];
      inherit doCheck;
    }
    ++ [
      (output.strip {
        inherit python binutils;
        paths = elfPaths;
        flags = stripFlags;
      })
      (output.libtool {
        inherit python;
        paths = [ "lib/libmpfr.la" ];
      })
      (output.rpaths {
        inherit
          python
          binutils
          patchelf
          dlopenDirectories
          ;
        paths = elfPaths;
      })
      (output.development {
        inherit python;
        libraries = [ gmp ];
      })
      (output.checkSymlinks {
        inherit python;
        paths = [
          "lib/libmpfr.so"
          "lib/libmpfr.so.6"
        ];
      })
      (output.checkPaths {
        inherit python binutils patchelf;
        paths = elfPaths;
      })
    ];
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

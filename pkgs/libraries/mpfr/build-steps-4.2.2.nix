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
  steps =
    (import ../../../lib/build-steps.nix)
    // (import ../../../lib/owned-source-steps.nix { inherit lib; });
  output = import ../../../lib/native-output-steps.nix { inherit lib; };
  elfPaths = [ "lib/libmpfr.so.6.2.2" ];
in
final:
let
  environment = final.base.environment final.environment;
  command =
    name: run:
    environment
    // {
      inherit name run;
      cwd = "source";
    };
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
  environment = {
    tools = [ gnumake ];
    libraries = [ gmp ];
  };
  plan = steps.sequence [
    (steps.unpack {
      inherit src xz;
      tar = gnutar;
    })
    (steps.prepareAutotools {
      name = "mpfr.prepare";
      inherit bash python;
      base = final.base;
    })
    (command "mpfr.configure" ''
      export CONFIG_SHELL=${bash}/bin/bash
      export lt_cv_deplibs_check_method=pass_all
      ./configure --prefix="$out" --disable-static --disable-dependency-tracking --with-gmp=${lib.getDev gmp}
    '')
    (command "mpfr.build" ''${gnumake}/bin/make -j"$NIX_BUILD_CORES"'')
    (
      (command "mpfr.check" ''${gnumake}/bin/make -j"$NIX_BUILD_CORES" check'') // { enabled = doCheck; }
    )
    (command "mpfr.install" ''
      ${gnumake}/bin/make -j"$NIX_BUILD_CORES" install
      mkdir -p "$out/nix-support"
      cp "$TVP_SOURCE_ROOT/source-date-epoch" "$out/nix-support/source-date-epoch"
    '')
    (steps.split "mpfr.finalize")
    (output.copyArtifacts { inherit coreutils; })
    (output.relocateText {
      inherit python;
      paths = [
        "lib/pkgconfig/mpfr.pc"
        "lib/libmpfr.la"
      ];
    })
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
      base = final.base;
      libraries = final.runtime.libraries;
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
  runtime.libraries = [ gmp ];
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

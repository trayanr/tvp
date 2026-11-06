# MPFR 4.2.2: native source-GNU catalogue procedure; earlier host routes stay independent.
{
  tvp,
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
  sed,
  grep,
  gawk,
  diffutils,
  findutils,
  stripFlags ? [
    "-S"
    "-p"
  ],
  dlopenDirectories ? [ ],
  doCheck ? true,
}:
let
  inherit (tvp.builder) steps outputs;
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
    tools = [
      gnumake
      sed
      grep
      gawk
      diffutils
      findutils
    ];
    libraries = [ gmp ];
  };
  plan = steps.sequence [
    (steps.unpack {
      src = final.src;
      inherit xz findutils;
      tar = gnutar;
    })
    (steps.prepareAutotools {
      name = "mpfr.prepare";
      inherit bash python;
      base = final.base;
    })
    (steps.shebangs {
      name = "mpfr.source-shells";
      inherit python;
      paths = [
        "configure"
        "config.guess"
        "config.sub"
        "install-sh"
        "ltmain.sh"
        "missing"
        "depcomp"
        "test-driver"
      ];
      names = [
        "sh"
        "bash"
      ];
      interpreter = "${bash}/bin/bash";
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
    (outputs.copyArtifacts { inherit coreutils; })
    (outputs.relocateText {
      inherit python;
      paths = [
        "lib/pkgconfig/mpfr.pc"
        "lib/libmpfr.la"
      ];
    })
    (outputs.strip {
      inherit python binutils;
      paths = elfPaths;
      flags = stripFlags;
    })
    (outputs.libtool {
      inherit python;
      paths = [ "lib/libmpfr.la" ];
    })
    (outputs.rpaths {
      inherit
        python
        binutils
        patchelf
        ;
      dlopenDirectories = final.runtime.dlopenDirectories or [ ];
      base = final.base;
      libraries = final.runtime.libraries;
      paths = elfPaths;
    })
    (outputs.development {
      inherit python;
      libraries = [ gmp ];
    })
    (outputs.checkSymlinks {
      inherit python;
      paths = [
        "lib/libmpfr.so"
        "lib/libmpfr.so.6"
      ];
    })
    (outputs.checkPaths {
      inherit python binutils patchelf;
      paths = elfPaths;
    })
  ];
  runtime = {
    libraries = [ gmp ];
    inherit dlopenDirectories;
  };
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

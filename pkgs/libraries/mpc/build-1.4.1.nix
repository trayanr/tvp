# MPC 1.4.1: native source-GNU catalogue procedure; earlier host routes stay independent.
{
  tvp,
  lib,
  base,
  src,
  version,
  gmp,
  mpfr,
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
  elfPaths = [ "lib/libmpc.so.3.4.1" ];
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
  pname = "mpc";
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
    libraries = [
      gmp
      mpfr
    ];
  };
  plan = steps.sequence [
    (steps.unpack {
      src = final.src;
      inherit xz findutils;
      tar = gnutar;
    })
    (steps.prepareAutotools {
      name = "mpc.prepare";
      inherit bash python;
      base = final.base;
    })
    (steps.shebangs {
      name = "mpc.source-shells";
      inherit python;
      paths = [
        "configure"
        "build-aux"
      ];
      names = [
        "sh"
        "bash"
      ];
      interpreter = "${bash}/bin/bash";
    })
    (command "mpc.configure" ''
      export CONFIG_SHELL=${bash}/bin/bash
      export lt_cv_deplibs_check_method=pass_all
      ./configure --prefix="$out" --disable-static --disable-dependency-tracking --with-gmp=${lib.getDev gmp} --with-mpfr=${lib.getDev mpfr}
    '')
    (command "mpc.build" ''${gnumake}/bin/make -j"$NIX_BUILD_CORES"'')
    ((command "mpc.check" ''${gnumake}/bin/make -j"$NIX_BUILD_CORES" check'') // { enabled = doCheck; })
    (command "mpc.install" ''
      ${gnumake}/bin/make -j"$NIX_BUILD_CORES" install
      mkdir -p "$out/nix-support"
      cp "$TVP_SOURCE_ROOT/source-date-epoch" "$out/nix-support/source-date-epoch"
    '')
    (steps.split "mpc.finalize")
    (outputs.copyArtifacts { inherit coreutils; })
    (outputs.relocateText {
      inherit python;
      paths = [
        "lib/pkgconfig/mpc.pc"
        "lib/libmpc.la"
      ];
    })
    (outputs.strip {
      inherit python binutils;
      paths = elfPaths;
      flags = stripFlags;
    })
    (outputs.libtool {
      inherit python;
      paths = [ "lib/libmpc.la" ];
    })
    (outputs.rpaths {
      inherit
        python
        binutils
        patchelf
        ;
      dlopenDirectories = final.runtime.dlopenDirectories;
      base = final.base;
      libraries = final.runtime.libraries;
      paths = elfPaths;
    })
    (outputs.development {
      inherit python;
      libraries = [
        gmp
        mpfr
      ];
    })
    (outputs.checkSymlinks {
      inherit python;
      paths = [
        "lib/libmpc.so"
        "lib/libmpc.so.3"
      ];
    })
    (outputs.checkPaths {
      inherit python binutils patchelf;
      paths = elfPaths;
    })
  ];
  runtime = {
    libraries = [
      gmp
      mpfr
    ];
    inherit dlopenDirectories;
  };
  tvp.features = {
    shared = true;
    static = false;
  };
  meta = {
    description = "Multiple-precision complex arithmetic library";
    license = lib.licenses.lgpl3Plus;
    platforms = [ "x86_64-linux" ];
  };
}

# MPC 1.1.0: 1.1 uses gzip archives and pre-pkg-config layout.
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
  gzip,
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
  elfPaths = [ "lib" ];
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
  tools = {
    inherit
      gnumake
      gnutar
      gzip
      findutils
      python
      binutils
      patchelf
      sed
      grep
      gawk
      diffutils
      ;
  };
  libraries = {
    inherit gmp mpfr;
  };
  doCheck = doCheck;
  stripFlags = stripFlags;
  dlopenDirectories = dlopenDirectories;
  dependencyProviders = final.tools // final.libraries;
  environment = {
    tools = [
      final.tools.gnumake
      final.tools.sed
      final.tools.grep
      final.tools.gawk
      final.tools.diffutils
      final.tools.findutils
    ];
    libraries = [
      final.libraries.gmp
      final.libraries.mpfr
    ];
  };
  plan = steps.sequence [
    (steps.unpack {
      src = final.src;
      gzip = final.tools.gzip;
      compression = "gzip";
      findutils = final.tools.findutils;
      tar = final.tools.gnutar;
    })
    (steps.prepareAutotools {
      name = "mpc.prepare";
      bash = final.bash;
      python = final.tools.python;
      base = final.base;
    })
    (steps.shebangs {
      name = "mpc.source-shells";
      python = final.tools.python;
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
      interpreter = "${final.bash}/bin/bash";
    })
    (command "mpc.configure" ''
      export CONFIG_SHELL=${final.bash}/bin/bash
      export lt_cv_deplibs_check_method=pass_all
      ./configure --prefix="$out" --disable-static --disable-dependency-tracking --with-gmp=${lib.getDev final.libraries.gmp} --with-mpfr=${lib.getDev final.libraries.mpfr}
    '')
    (command "mpc.build" ''${final.tools.gnumake}/bin/make -j"$NIX_BUILD_CORES"'')
    (
      (command "mpc.check" ''${final.tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" check'')
      // {
        enabled = final.doCheck;
      }
    )
    (command "mpc.install" ''
      ${final.tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" install
      mkdir -p "$out/nix-support"
      cp "$TVP_SOURCE_ROOT/source-date-epoch" "$out/nix-support/source-date-epoch"
    '')
    (steps.split "mpc.finalize")
    (outputs.copyArtifacts { coreutils = final.coreutils; })
    (outputs.relocateText {
      python = final.tools.python;
      paths = [
        "lib/libmpc.la"
      ];
    })
    (outputs.strip {
      python = final.tools.python;
      binutils = final.tools.binutils;
      paths = elfPaths;
      flags = final.stripFlags;
    })
    (outputs.libtool {
      python = final.tools.python;
      paths = [ "lib/libmpc.la" ];
    })
    (outputs.rpaths {
      python = final.tools.python;
      binutils = final.tools.binutils;
      patchelf = final.tools.patchelf;
      dlopenDirectories = final.runtime.dlopenDirectories or [ ];
      base = final.base;
      libraries = final.runtime.libraries;
      paths = elfPaths;
    })
    (outputs.development {
      python = final.tools.python;
      libraries = [
        final.libraries.gmp
        final.libraries.mpfr
      ];
    })
    (outputs.checkSymlinks {
      python = final.tools.python;
      paths = [
        "lib/libmpc.so"
        "lib/libmpc.so.3"
      ];
    })
    (outputs.checkPaths {
      python = final.tools.python;
      binutils = final.tools.binutils;
      patchelf = final.tools.patchelf;
      paths = elfPaths;
    })
  ];
  runtime = {
    libraries = [
      final.libraries.gmp
      final.libraries.mpfr
    ];
    dlopenDirectories = final.dlopenDirectories;
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

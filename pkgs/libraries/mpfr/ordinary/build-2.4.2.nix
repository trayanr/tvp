# Independent public compatibility procedure: mpfr 2.4.2 through 3.1.6.
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
  checkCFlags ? [ "-std=gnu17" ],
  float128 ? false,
  mpfrRoundingNames ? true,
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
  pname = "mpfr";
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
      xz
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
    inherit gmp;
  };
  inherit doCheck checkCFlags float128 mpfrRoundingNames;
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
    libraries = [ final.libraries.gmp ];
  };
  productionPlan = steps.sequence [
    (steps.unpack {
      src = final.src;
      xz = final.tools.xz;
      findutils = final.tools.findutils;
      tar = final.tools.gnutar;
    })
    (steps.prepareAutotools {
      name = "mpfr.prepare";
      bash = final.bash;
      python = final.tools.python;
      base = final.base;
    })
    (steps.shebangs {
      name = "mpfr.source-shells";
      python = final.tools.python;
      paths = [
        "configure"
        "config.guess"
        "config.sub"
        "install-sh"
        "ltmain.sh"
        "missing"
        "depcomp"
        "compile"
      ] ++ lib.optional (final.version == "3.1.6") "test-driver";
      names = [
        "sh"
        "bash"
      ];
      interpreter = "${final.bash}/bin/bash";
    })
    (command "mpfr.configure" ''
      export CONFIG_SHELL=${final.bash}/bin/bash
      export lt_cv_deplibs_check_method=pass_all
      ./configure --prefix="$out" --disable-static --disable-dependency-tracking ${lib.optionalString (!final.float128) "--disable-float128"} --with-gmp=${lib.getDev final.libraries.gmp}
    '')
    (command "mpfr.build" ''${final.tools.gnumake}/bin/make -j"$NIX_BUILD_CORES"'')
    (command "mpfr.install" ''
      ${final.tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" install
      mkdir -p "$out/nix-support"
      cp "$TVP_SOURCE_ROOT/source-date-epoch" "$out/nix-support/source-date-epoch"
    '')
  ];
  upstreamPlan = builtins.filter (step: step.name != "mpfr.install") final.productionPlan;
  upstreamCheck = (command "mpfr.check" ''
    export NIX_CFLAGS_COMPILE="$NIX_CFLAGS_COMPILE ${lib.concatStringsSep " " final.checkCFlags}"
    ${final.tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" check
  '') // { enabled = final.doCheck; };
  plan = final.productionPlan ++ [
    (steps.split "mpfr.finalize")
    (outputs.copyArtifacts { coreutils = final.coreutils; })
    (outputs.relocateText {
      python = final.tools.python;
      paths = [
        "lib/libmpfr.la"
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
      paths = [ "lib/libmpfr.la" ];
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
      libraries = [ final.libraries.gmp ];
    })
    (outputs.checkSymlinks {
      python = final.tools.python;
      paths = [
        "lib/libmpfr.so"
        "lib/libmpfr.so.${if lib.versionOlder final.version "3.0" then "1" else "4"}"
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
    libraries = [ final.libraries.gmp ];
    dlopenDirectories = final.dlopenDirectories;
  };
  tvp.features = {
    float128 = final.float128;
    mpfrRoundingNames = final.mpfrRoundingNames;
  };
  meta = {
    description = "Correctly rounded multiple-precision floating-point arithmetic";
    license = lib.licenses.lgpl3Plus;
    platforms = lib.platforms.unix;
  };
}

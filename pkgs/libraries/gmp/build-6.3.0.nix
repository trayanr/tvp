# GMP 6.3.0: native source-GNU catalogue procedure; earlier host routes stay independent.
{
  tvp,
  lib,
  base,
  src,
  version,
  bash,
  coreutils,
  gnumake,
  gnutar,
  xz,
  findutils,
  m4,
  python,
  binutils,
  patchelf,
  sed,
  grep,
  gawk,
  diffutils,
  doCheck ? true,
}:
let
  inherit (tvp.builder) steps outputs;
  elfPaths = [
    "lib/libgmp.so.10.5.0"
    "lib/libgmpxx.so.4.7.0"
  ];
in
final:
let
  command =
    name: run:
    (final.base.environment final.environment)
    // {
      inherit name run;
      cwd = "source";
    };
in
{
  pname = "gmp";
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
      m4
      sed
      grep
      gawk
      diffutils
      findutils
    ];
    overrides.values = {
      M4 = "${m4}/bin/m4";
      # GMP's configure probes predate GCC's default C23 semantics.
      CFLAGS = "-O2 -std=gnu17";
    };
  };
  plan = [
    (steps.unpack {
      src = final.src;
      inherit xz findutils;
      tar = gnutar;
    })
    (steps.prepareAutotools {
      name = "gmp.prepare";
      inherit bash python;
      base = final.base;
    })
    (steps.shebangs {
      name = "gmp.source-shells";
      inherit python;
      paths = [
        "configure"
        "configfsf.guess"
        "configfsf.sub"
        "config.guess"
        "config.sub"
        "install-sh"
        "ltmain.sh"
        "missing"
        "test-driver"
        "compile"
        "mpn/x86/t-zdisp.sh"
      ];
      names = [
        "sh"
        "bash"
      ];
      interpreter = "${bash}/bin/bash";
    })
    (command "gmp.configure" ''
      export CONFIG_SHELL=${bash}/bin/bash
      export lt_cv_deplibs_check_method=pass_all
      ./configure --prefix="$out" --build=${final.base.platform.config} --host=${final.base.platform.config} \
        --enable-cxx --enable-shared --enable-static --with-pic --disable-dependency-tracking
    '')
    (command "gmp.build" ''${gnumake}/bin/make -j"$NIX_BUILD_CORES"'')
    ((command "gmp.check" ''${gnumake}/bin/make -j"$NIX_BUILD_CORES" check'') // { enabled = doCheck; })
    (command "gmp.install" ''
      ${gnumake}/bin/make -j"$NIX_BUILD_CORES" install
      mkdir -p "$out/nix-support"
      cp "$TVP_SOURCE_ROOT/source-date-epoch" "$out/nix-support/source-date-epoch"
    '')
    (steps.split "gmp.finalize")
    (outputs.copyArtifacts { inherit coreutils; })
    (outputs.relocateText {
      inherit python;
      paths = [
        "lib/pkgconfig"
        "lib/libgmp.la"
        "lib/libgmpxx.la"
      ];
    })
    (outputs.strip {
      inherit python binutils;
      paths = elfPaths;
    })
    (outputs.stripArchives {
      inherit python binutils;
      paths = [ "lib" ];
    })
    (outputs.libtool {
      inherit python;
      paths = [
        "lib/libgmp.la"
        "lib/libgmpxx.la"
      ];
    })
    (outputs.rpaths {
      inherit python binutils patchelf;
      base = final.base;
      libraries = final.runtime.libraries;
      paths = elfPaths;
    })
    (outputs.development {
      inherit python;
      libraries = [ ];
    })
    (outputs.checkSymlinks {
      inherit python;
      paths = [
        "lib/libgmp.so"
        "lib/libgmp.so.10"
        "lib/libgmpxx.so"
        "lib/libgmpxx.so.4"
      ];
    })
    (outputs.checkPaths {
      inherit python binutils patchelf;
      paths = elfPaths;
    })
  ];
  runtime.libraries = [ ];
  tvp.reportedVersion = version;
  tvp.features = {
    shared = true;
    static = true;
    cxx = true;
    assembly = true;
  };
  meta = {
    description = "GNU multiple precision arithmetic with native assembly and C++";
    license = lib.licenses.lgpl3Plus;
    platforms = [ "x86_64-linux" ];
  };
}

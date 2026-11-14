# GMP 6.2.0: 6.2 introduces gmp/gmpxx pkg-config metadata; serves 6.2.x.
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
    "lib"
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
  tools = {
    inherit
      gnumake
      gnutar
      xz
      findutils
      m4
      python
      binutils
      patchelf
      sed
      grep
      gawk
      diffutils
      ;
  };
  doCheck = doCheck;
  dependencyProviders = final.tools;
  environment = {
    tools = [
      final.tools.gnumake
      final.tools.m4
      final.tools.sed
      final.tools.grep
      final.tools.gawk
      final.tools.diffutils
      final.tools.findutils
    ];
    overrides.values = {
      M4 = "${final.tools.m4}/bin/m4";
      # GMP's configure probes predate GCC's default C23 semantics.
      CFLAGS = "-O2 -std=gnu17";
    };
  };
  plan = [
    (steps.unpack {
      src = final.src;
      xz = final.tools.xz;
      findutils = final.tools.findutils;
      tar = final.tools.gnutar;
    })
    (steps.prepareAutotools {
      name = "gmp.prepare";
      bash = final.bash;
      python = final.tools.python;
      base = final.base;
    })
    (steps.shebangs {
      name = "gmp.source-shells";
      python = final.tools.python;
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
      interpreter = "${final.bash}/bin/bash";
    })
    (command "gmp.configure" ''
      export CONFIG_SHELL=${final.bash}/bin/bash
      export lt_cv_deplibs_check_method=pass_all
      ./configure --prefix="$out" --build=${final.base.platform.config} --host=${final.base.platform.config} \
        --enable-cxx --enable-shared --enable-static --with-pic --disable-dependency-tracking
    '')
    (command "gmp.build" ''${final.tools.gnumake}/bin/make -j"$NIX_BUILD_CORES"'')
    (
      (command "gmp.check" ''${final.tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" check'')
      // {
        enabled = final.doCheck;
      }
    )
    (command "gmp.install" ''
      ${final.tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" install
      mkdir -p "$out/nix-support"
      cp "$TVP_SOURCE_ROOT/source-date-epoch" "$out/nix-support/source-date-epoch"
    '')
    (steps.split "gmp.finalize")
    (outputs.copyArtifacts { coreutils = final.coreutils; })
    (outputs.relocateText {
      python = final.tools.python;
      paths = [
        "lib/pkgconfig"
        "lib/libgmp.la"
        "lib/libgmpxx.la"
      ];
    })
    (outputs.strip {
      python = final.tools.python;
      binutils = final.tools.binutils;
      paths = elfPaths;
    })
    (outputs.stripArchives {
      python = final.tools.python;
      binutils = final.tools.binutils;
      paths = [ "lib" ];
    })
    (outputs.libtool {
      python = final.tools.python;
      paths = [
        "lib/libgmp.la"
        "lib/libgmpxx.la"
      ];
    })
    (outputs.rpaths {
      python = final.tools.python;
      binutils = final.tools.binutils;
      patchelf = final.tools.patchelf;
      base = final.base;
      libraries = final.runtime.libraries;
      dlopenDirectories = final.runtime.dlopenDirectories or [ ];
      paths = elfPaths;
    })
    (outputs.development {
      python = final.tools.python;
      libraries = [ ];
    })
    (outputs.checkSymlinks {
      python = final.tools.python;
      paths = [
        "lib/libgmp.so"
        "lib/libgmp.so.10"
        "lib/libgmpxx.so"
        "lib/libgmpxx.so.4"
      ];
    })
    (outputs.checkPaths {
      python = final.tools.python;
      binutils = final.tools.binutils;
      patchelf = final.tools.patchelf;
      paths = elfPaths;
    })
  ];
  runtime.libraries = [ ];
  tvp.reportedVersion = final.version;
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

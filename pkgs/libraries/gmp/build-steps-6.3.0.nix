# Modern, opt-in owned recipe. Historical GMP producers remain untouched.
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
    ];
    overrides.values = {
      M4 = "${m4}/bin/m4";
      # GMP's configure probes predate GCC's default C23 semantics.
      CFLAGS = "-O2 -std=gnu17";
    };
  };
  plan = [
    (steps.unpack {
      inherit src xz findutils;
      tar = gnutar;
    })
    (steps.prepareAutotools {
      name = "gmp.prepare";
      inherit bash python;
      base = final.base;
    })
    (command "gmp.configure" ''
      export CONFIG_SHELL=${bash}/bin/bash
      export lt_cv_deplibs_check_method=pass_all
      ./configure --prefix="$out" --build=${base.platform.config} --host=${base.platform.config} \
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

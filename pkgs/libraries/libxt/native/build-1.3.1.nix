# Ordinary 1.3.1 only. Frozen construction retains the independent legacy recipe.
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
  sed,
  grep,
  gawk,
  diffutils,
  python,
  perl,
  binutils,
  patchelf,
  pkgConfig,
  libsm,
  libice,
  libx11,
  xorgproto,
  xtrans,
  libxcb,
  libxau,
  libxdmcp,
  libraryDirectory ? "lib",
  doCheck ? true,
}:
final:
let
  inherit (tvp.builder) steps;
  xorg = import ../../../../lib/xorg-library-steps.nix { inherit lib; };
  command =
    name: run:
    (final.base.environment final.environment)
    // {
      name = "libxt.${name}";
      cwd = "source";
      inherit run;
    };
  make = ''${final.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${final.bash}/bin/bash'';
in
{
  pname = "libxt";
  inherit
    base
    src
    version
    libraryDirectory
    doCheck
    bash
    coreutils
    gnumake
    gnutar
    xz
    findutils
    sed
    grep
    gawk
    diffutils
    python
    perl
    binutils
    patchelf
    pkgConfig
    libsm
    libice
    libx11
    xorgproto
    xtrans
    libxcb
    libxau
    libxdmcp
    ;
  environment = {
    tools = [
      final.perl
      final.pkgConfig
      final.gnumake
      final.sed
      final.grep
      final.gawk
      final.diffutils
      final.findutils
    ];
    libraries = [
      final.libsm
      final.libice
      final.libx11
      final.xorgproto
      final.xtrans
      final.libxcb
      final.libxau
      final.libxdmcp
    ];
  };
  runtime.libraries = [
    final.libsm
    final.libice
    final.libx11
    final.libxcb
    final.libxau
    final.libxdmcp
  ];
  development = package: {
    libraryDirectories = [ "${package}/${final.libraryDirectory}" ];
    pkgconfig = [
      "${package}/${final.libraryDirectory}/pkgconfig"
      "${package}/share/pkgconfig"
    ];
  };
  plan = steps.sequence [
    (steps.unpack {
      src = final.src;
      tar = final.gnutar;
      xz = final.xz;
      findutils = final.findutils;
    })
    (steps.prepareAutotools {
      name = "libxt.prepare";
      bash = final.bash;
      python = final.python;
      base = final.base;
    })
    (command "configure" ''
      export CONFIG_SHELL=${final.bash}/bin/bash SHELL=${final.bash}/bin/bash
      ./configure --prefix="$out" --libdir="$out"/${lib.escapeShellArg final.libraryDirectory}
    '')
    (command "build" make)
    ((command "check" "${make} check") // { enabled = final.doCheck; })
    (command "install" ''
      ${make} install
      mkdir -p "$out/nix-support"
      cp "$TVP_SOURCE_ROOT/source-date-epoch" "$out/nix-support/source-date-epoch"
    '')
    (xorg.finish {
      outputs = tvp.builder.outputs;
      inherit (final)
        bash
        python
        binutils
        patchelf
        base
        libraryDirectory
        ;
      runtimeLibraries = final.runtime.libraries;
      developmentLibraries = [
        final.libsm
        final.libice
        final.libx11
        final.xorgproto
        final.xtrans
        final.libxcb
        final.libxau
        final.libxdmcp
      ];
    })
  ];
  tvp.features = {
    shared = true;
    static = true;
  };
  meta = {
    description = "Owned ordinary libXt X.Org extension library";
    homepage = "https://www.x.org/";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
  };
}

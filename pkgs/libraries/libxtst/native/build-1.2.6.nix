# Ordinary 1.2.6 only. Frozen construction retains the independent legacy recipe.
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
  libx11,
  libxext,
  libxi,
  xorgproto,
  xtrans,
  libxcb,
  libxau,
  libxdmcp,
  libxfixes,
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
      name = "libxtst.${name}";
      cwd = "source";
      inherit run;
    };
  make = ''${final.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${final.bash}/bin/bash'';
in
{
  pname = "libxtst";
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
    libx11
    libxext
    libxi
    xorgproto
    xtrans
    libxcb
    libxau
    libxdmcp
    libxfixes
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
      final.libx11
      final.libxext
      final.libxi
      final.xorgproto
      final.xtrans
      final.libxcb
      final.libxau
      final.libxdmcp
      final.libxfixes
    ];
  };
  runtime.libraries = [
    final.libx11
    final.libxext
    final.libxi
    final.libxcb
    final.libxau
    final.libxdmcp
    final.libxfixes
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
      name = "libxtst.prepare";
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
        final.libx11
        final.libxext
        final.libxi
        final.xorgproto
        final.xtrans
        final.libxcb
        final.libxau
        final.libxdmcp
        final.libxfixes
      ];
    })
  ];
  tvp.features = {
    shared = true;
    static = true;
  };
  meta = {
    description = "Owned ordinary libXtst X.Org extension library";
    homepage = "https://www.x.org/";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
  };
}

# Ordinary 1.8.14 only. Frozen construction retains the independent legacy recipe.
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
  xorgproto,
  xtrans,
  libxcb,
  libxau,
  libxdmcp,
  doCheck ? true,
}:
final:
let
  inherit (tvp.builder) steps outputs;
  command =
    name: run:
    (final.base.environment final.environment)
    // {
      name = "libx11.${name}";
      cwd = "source";
      inherit run;
    };
  make = ''${final.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${final.bash}/bin/bash'';
in
{
  pname = "libx11";
  inherit
    base
    src
    version
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
      final.xorgproto
      final.xtrans
      final.libxcb
      final.libxau
      final.libxdmcp
    ];
  };
  runtime.libraries = [
    final.libxcb
    final.libxau
    final.libxdmcp
  ];
  plan = steps.sequence [
    (steps.unpack {
      src = final.src;
      tar = final.gnutar;
      xz = final.xz;
      findutils = final.findutils;
    })
    (steps.prepareAutotools {
      name = "libx11.prepare";
      bash = final.bash;
      python = final.python;
      base = final.base;
    })
    (command "configure" ''
      export CONFIG_SHELL=${final.bash}/bin/bash SHELL=${final.bash}/bin/bash
      ./configure --prefix="$out" --libdir="$out/lib"
    '')
    (command "build" make)
    ((command "check" "${make} check") // { enabled = final.doCheck; })
    (command "install" ''
      ${make} install
      mkdir -p "$out/nix-support"
      cp "$TVP_SOURCE_ROOT/source-date-epoch" "$out/nix-support/source-date-epoch"
    '')
    (outputs.shebangs {
      python = final.python;
      paths = [ "lib" ];
      names = [
        "sh"
        "bash"
      ];
      interpreter = "${final.bash}/bin/bash";
    })
    (outputs.strip {
      python = final.python;
      binutils = final.binutils;
      paths = [ "lib" ];
      elfKinds = [ "runtime" ];
    })
    (outputs.stripArchives {
      python = final.python;
      binutils = final.binutils;
      paths = [ "lib" ];
    })
    (outputs.rpaths {
      python = final.python;
      binutils = final.binutils;
      patchelf = final.patchelf;
      base = final.base;
      libraries = final.runtime.libraries;
      paths = [ "lib" ];
      elfKinds = [ "runtime" ];
    })
    (outputs.checkPaths {
      python = final.python;
      binutils = final.binutils;
      patchelf = final.patchelf;
      paths = [ "lib" ];
      elfKinds = [ "runtime" ];
    })
    (outputs.development {
      python = final.python;
      libraries = [
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
    description = "Owned ordinary libx11 X.Org foundation";
    homepage = "https://www.x.org/";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
  };
}

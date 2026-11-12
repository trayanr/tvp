# Ordinary 1.17.0 only. Frozen construction retains the independent legacy recipe.
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
  binutils,
  patchelf,
  pkgConfig,
  xcb-proto,
  libxau,
  libxdmcp,
  xorgproto,
  generatorPython,
  doCheck ? true,
}:
final:
let
  inherit (tvp.builder) steps outputs;
  command =
    name: run:
    (final.base.environment final.environment)
    // {
      name = "libxcb.${name}";
      cwd = "source";
      inherit run;
    };
  make = ''${final.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${final.bash}/bin/bash'';
in
{
  pname = "libxcb";
  artifactName = "${final.pname}-${final.version}";
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
    binutils
    patchelf
    pkgConfig
    xcb-proto
    libxau
    libxdmcp
    xorgproto
    generatorPython
    ;
  outputs = [ "out" ];
  environment = {
    tools = [
      final.pkgConfig
      final.gnumake
      final.sed
      final.grep
      final.gawk
      final.diffutils
      final.findutils
      final.generatorPython
    ];
    libraries = [
      final.xcb-proto
      final.libxau
      final.libxdmcp
      final.xorgproto
    ];
    overrides.values.PYTHON = "${final.generatorPython}/bin/python3";
    overrides.values.PYTHONPATH = final.xcb-proto.development.pythonModuleDirectory;
  };
  runtime.libraries = [
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
      name = "libxcb.prepare";
      bash = final.bash;
      python = final.python;
      base = final.base;
    })
    (command "configure" ''
      export CONFIG_SHELL=${final.bash}/bin/bash SHELL=${final.bash}/bin/bash
      ./configure --prefix="$out" --libdir="$out/lib" --enable-xinput --enable-xkb
    '')
    (command "build" make)
    (command "install" ''
      ${make} install
      mkdir -p "$out/nix-support"
      cp "$TVP_SOURCE_ROOT/source-date-epoch" "$out/nix-support/source-date-epoch"
    '')
    (steps.split "libxcb.finalize")
    (tvp.builder.outputs.copyArtifacts {
      coreutils = final.coreutils;
      outputs = if final.outputs == [ "out" ] then null else final.outputs;
    })
    {
      name = "libxcb.relocate";
      tools = [ final.python ];
      run = ''${final.python}/bin/python3 -B ${../../jdk-support-relocate.py} "$out" "$TVP_ARTIFACT_ROOT" ${
        if builtins.elem "evidence" final.outputs then
          ''"$evidence" "''${TVP_ARTIFACT_OUTPUTS[evidence]}"''
        else
          ""
      }'';
    }
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
        final.libxau
        final.libxdmcp
        final.xorgproto
      ];
    })
  ];
  tvp.features = {
    shared = true;
    static = true;
  };
  meta = {
    description = "Owned ordinary libxcb X.Org foundation";
    homepage = "https://www.x.org/";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
  };
}

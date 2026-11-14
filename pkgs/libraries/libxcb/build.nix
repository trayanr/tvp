# Complete libxcb 1.17.0 procedure; earlier providers stay explicit.
{
  tvp,
  lib,
  base,
  src,
  version,
  generatorPython,
  libxau,
  libxdmcp,
  pkgConfig,
  xcb-proto,
  xorgproto,
  doCheck ? true,
}:
final:
let
  context = tvp.builder.forBase final.base;
  inherit (context) steps outputs tools;
  command =
    name: run:
    (final.base.environment final.environment)
    // {
      name = "libxcb.${name}";
      cwd = "source";
      inherit run;
    };
  make = ''${tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${final.bash}/bin/bash'';
in
{
  pname = "libxcb";
  artifactName = "${final.pname}-${final.version}";
  inherit
    base
    src
    version
    doCheck
    pkgConfig
    xcb-proto
    libxau
    libxdmcp
    xorgproto
    generatorPython
    ;
  inherit (tools) bash coreutils;
  outputs = [ "out" ];
  environment = {
    tools = [
      final.pkgConfig
      tools.gnumake
      tools.sed
      tools.grep
      tools.gawk
      tools.diffutils
      tools.findutils
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
    })
    (steps.prepareAutotools {
      name = "libxcb.prepare";
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
    (outputs.copyArtifacts {
      outputs = final.outputs;
    })
    {
      name = "libxcb.relocate";
      tools = [ tools.python ];
      run = ''${tools.python}/bin/python3 -B ${../jdk-support-relocate.py} "$out" "$TVP_ARTIFACT_ROOT" ${
        if builtins.elem "evidence" final.outputs then
          ''"$evidence" "''${TVP_ARTIFACT_OUTPUTS[evidence]}"''
        else
          ""
      }'';
    }
    (outputs.shebangs {
      paths = [ "lib" ];
      names = [
        "sh"
        "bash"
      ];
      interpreter = "${final.bash}/bin/bash";
    })
    (outputs.strip {
      paths = [ "lib" ];
      elfKinds = [ "runtime" ];
    })
    (outputs.stripArchives {
      paths = [ "lib" ];
    })
    (outputs.rpaths {
      libraries = final.runtime.libraries;
      paths = [ "lib" ];
      elfKinds = [ "runtime" ];
    })
    (outputs.checkPaths {
      paths = [ "lib" ];
      elfKinds = [ "runtime" ];
    })
    (outputs.development {
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

# Complete libxrender 0.9.13 procedure; earlier providers stay explicit.
{
  tvp,
  lib,
  base,
  src,
  version,
  libx11,
  libxau,
  libxcb,
  libxdmcp,
  pkgConfig,
  xorgproto,
  xtrans,
  installedInterface ? { },
  doCheck ? true,
}:
final:
let
  context = tvp.builder.forBase final.base;
  inherit (context) steps outputs tools;
  xorg = import ../../../lib/xorg-library-steps.nix { inherit lib context; };
  command =
    name: run:
    (final.base.environment final.environment)
    // {
      name = "libxrender.${name}";
      cwd = "source";
      inherit run;
    };
  make = ''${tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${final.bash}/bin/bash'';
in
{
  pname = "libxrender";
  artifactName = "${final.pname}-${final.version}";
  inherit
    base
    src
    version
    doCheck
    pkgConfig
    libx11
    xorgproto
    xtrans
    libxcb
    libxau
    libxdmcp
    ;
  inherit (tools) bash coreutils;
  installedInterface = {
    libraryDirectory = "lib";
  } // installedInterface;
  outputs = [ "out" ];
  environment = {
    tools = [
      tools.perl
      final.pkgConfig
      tools.gnumake
      tools.sed
      tools.grep
      tools.gawk
      tools.diffutils
      tools.findutils
    ];
    libraries = [
      final.libx11
      final.xorgproto
      final.xtrans
      final.libxcb
      final.libxau
      final.libxdmcp
    ];
  };
  runtime.libraries = [
    final.libx11
    final.libxcb
    final.libxau
    final.libxdmcp
  ];
  development = package: {
    libraryDirectories = [ "${package}/${final.installedInterface.libraryDirectory}" ];
    pkgconfig = [
      "${package}/${final.installedInterface.libraryDirectory}/pkgconfig"
      "${package}/share/pkgconfig"
    ];
  };
  plan = steps.sequence [
    (steps.unpack {
      src = final.src;
    })
    (steps.prepareAutotools {
      name = "libxrender.prepare";
    })
    (command "configure" ''
      export CONFIG_SHELL=${final.bash}/bin/bash SHELL=${final.bash}/bin/bash
      ./configure --prefix="$out" --libdir="$out"/${lib.escapeShellArg final.installedInterface.libraryDirectory}
    '')
    (command "build" make)
    (command "install" ''
      ${make} install
      mkdir -p "$out/nix-support"
      cp "$TVP_SOURCE_ROOT/source-date-epoch" "$out/nix-support/source-date-epoch"
    '')
    (steps.split "libxrender.finalize")
    (outputs.copyArtifacts {
      outputs = final.outputs;
    })
    {
      name = "libxrender.relocate";
      tools = [ tools.python ];
      run = ''${tools.python}/bin/python3 -B ${../jdk-support-relocate.py} "$out" "$TVP_ARTIFACT_ROOT" ${
        if builtins.elem "evidence" final.outputs then
          ''"$evidence" "''${TVP_ARTIFACT_OUTPUTS[evidence]}"''
        else
          ""
      }'';
    }
    (xorg.finish {
      base = final.base;
      libraryDirectory = final.installedInterface.libraryDirectory;
      runtimeLibraries = final.runtime.libraries;
      developmentLibraries = [
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
    description = "Owned ordinary libXrender X.Org extension library";
    homepage = "https://www.x.org/";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
  };
}

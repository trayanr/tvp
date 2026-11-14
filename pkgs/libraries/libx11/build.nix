# Complete libx11 1.8.14 procedure; earlier providers stay explicit.
{
  tvp,
  lib,
  base,
  src,
  version,
  libxau,
  libxcb,
  libxdmcp,
  pkgConfig,
  xorgproto,
  xtrans,
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
      name = "libx11.${name}";
      cwd = "source";
      inherit run;
    };
  make = ''${tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${final.bash}/bin/bash'';
in
{
  pname = "libx11";
  artifactName = "${final.pname}-${final.version}";
  inherit
    base
    src
    version
    doCheck
    pkgConfig
    xorgproto
    xtrans
    libxcb
    libxau
    libxdmcp
    ;
  inherit (tools) bash coreutils;
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
    })
    (steps.prepareAutotools {
      name = "libx11.prepare";
    })
    (command "configure" ''
      export CONFIG_SHELL=${final.bash}/bin/bash SHELL=${final.bash}/bin/bash
      ./configure --prefix="$out" --libdir="$out/lib"
    '')
    (command "build" make)
    (command "install" ''
      ${make} install
      mkdir -p "$out/nix-support"
      cp "$TVP_SOURCE_ROOT/source-date-epoch" "$out/nix-support/source-date-epoch"
    '')
    (steps.split "libx11.finalize")
    (outputs.copyArtifacts {
      outputs = final.outputs;
    })
    {
      name = "libx11.relocate";
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

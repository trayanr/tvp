# Complete libice 1.1.2 procedure; earlier providers stay explicit.
{
  tvp,
  lib,
  base,
  src,
  version,
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
      name = "libice.${name}";
      cwd = "source";
      inherit run;
    };
  make = ''${tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${final.bash}/bin/bash'';
in
{
  pname = "libice";
  artifactName = "${final.pname}-${final.version}";
  inherit
    base
    src
    version
    doCheck
    pkgConfig
    xorgproto
    xtrans
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
    ];
    libraries = [
      final.xorgproto
      final.xtrans
    ];
  };
  runtime.libraries = [ ];
  plan = steps.sequence [
    (steps.unpack {
      src = final.src;
    })
    (steps.prepareAutotools {
      name = "libice.prepare";
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
    (steps.split "libice.finalize")
    (outputs.copyArtifacts {
      outputs = final.outputs;
    })
    {
      name = "libice.relocate";
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
      ];
    })
  ];
  tvp.features = {
    shared = true;
    static = true;
  };
  meta = {
    description = "Owned ordinary libice X.Org foundation";
    homepage = "https://www.x.org/";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
  };
}

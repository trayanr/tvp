# Complete xcb-proto 1.17.0 procedure; earlier providers stay explicit.
{
  tvp,
  lib,
  base,
  src,
  version,
  generatorPython,
  pkgConfig,
  doCheck ? true,
}:
final:
let
  context = tvp.builder.forBase final.base;
  inherit (context) steps outputs tools;
  command =
    name:
    steps.command {
      environment = final.environment;
    } "xcb-proto.${name}";
  make = ''${tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${final.bash}/bin/bash'';
in
{
  pname = "xcb-proto";
  artifactName = "${final.pname}-${final.version}";
  inherit
    base
    src
    version
    doCheck
    pkgConfig
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
    libraries = [ ];
    overrides.values.PYTHON = "${final.generatorPython}/bin/python3";
  };
  runtime.libraries = [ ];
  pythonLayout = "lib/python${lib.versions.majorMinor final.generatorPython.version}/site-packages";
  development = output: { pythonModuleDirectory = "${output}/${final.pythonLayout}"; };
  plan = steps.sequence [
    (steps.unpack {
      src = final.src;
    })
    (steps.prepareAutotools {
      name = "xcb-proto.prepare";
    })
    (command "configure" ''
      export CONFIG_SHELL=${final.bash}/bin/bash SHELL=${final.bash}/bin/bash
      # AM_PATH_PYTHON assigns both directories from these cache variables.
      ./configure --prefix="$out" --libdir="$out/lib" \
        am_cv_python_pythondir="$out"/${lib.escapeShellArg final.pythonLayout} \
        am_cv_python_pyexecdir="$out"/${lib.escapeShellArg final.pythonLayout}
    '')
    (command "build" make)
    (command "install" ''
      ${make} install
      mkdir -p "$out/nix-support"
      cp "$TVP_SOURCE_ROOT/source-date-epoch" "$out/nix-support/source-date-epoch"
    '')

    (steps.split "xcb-proto.finalize")
    (outputs.copyArtifacts {
      outputs = final.outputs;
    })
    {
      name = "xcb-proto.relocate";
      tools = [ tools.python ];
      run = ''${tools.python}/bin/python3 -B ${../jdk-support-relocate.py} "$out" "$TVP_ARTIFACT_ROOT" ${
        if builtins.elem "evidence" final.outputs then
          ''"$evidence" "''${TVP_ARTIFACT_OUTPUTS[evidence]}"''
        else
          ""
      }'';
    }
    (outputs.development {
      libraries = [ ];
    })
  ];
  tvp.features = {
    shared = false;
    static = false;
  };
  meta = {
    description = "Owned ordinary xcb-proto X.Org foundation";
    homepage = "https://www.x.org/";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
  };
}

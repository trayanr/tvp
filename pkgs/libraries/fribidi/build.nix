{
  tvp,
  lib,
  base,
  src,
  version,
  meson,
}:
final:
let
  inherit (tvp.builder.forBase final.base) steps outputs tools;
  native = import ../../../lib/native-steps.nix { inherit lib; };
  paths = [
    "bin"
    "lib"
  ];
in
{
  pname = "fribidi";
  inherit
    base
    src
    version
    meson
    ;
  inherit (tools) bash coreutils;
  outputs = [ "out" ];
  runtime.libraries = [ ];
  plan = steps.sequence [
    (steps.unpack {
      src = final.src;
      compression = "xz";
    })
    (native.meson {
      name = "fribidi";
      inherit (final) meson;
      inherit (tools) ninja pkg-config;
      mesonFlags = [
        "-Ddefault_library=shared"
        "-Dtests=false"
        "-Ddocs=false"
      ];
      doCheck = false;
    })
    (steps.split "fribidi.finalize")
    (outputs.copyArtifacts { outputs = final.outputs; })
    (outputs.relocateText { paths = [ "lib/pkgconfig" ]; })
    (outputs.strip { inherit paths; })
    (outputs.rpaths {
      inherit paths;
      libraries = final.runtime.libraries;
    })
    {
      name = "fribidi.bind-self-libraries";
      tools = [
        tools.binutils
        tools.patchelf
        tools.python
      ];
      run = ''${tools.python}/bin/python3 -B ${../../../lib/append-self-rpaths.py} "$out" ${
        lib.escapeShellArg (
          builtins.toJSON {
            inherit paths;
            directories = [ "lib" ];
            readelf = "${tools.binutils}/bin/readelf";
            patchelf = "${tools.patchelf}/bin/patchelf";
          }
        )
      } ${../../../lib/native-output}'';
    }
    (outputs.checkPaths { inherit paths; })
  ];
  meta = {
    description = "Unicode bidirectional text algorithm";
    homepage = "https://github.com/fribidi/fribidi";
    license = lib.licenses.lgpl21Plus;
    platforms = [ "x86_64-linux" ];
  };
}

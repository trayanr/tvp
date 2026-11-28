{
  tvp,
  lib,
  base,
  src,
  version,
}:
final:
let
  inherit (tvp.builder.forBase final.base) steps outputs tools;
  environment = final.base.environment final.environment;
  paths = [
    "bin"
    "lib"
  ];
in
{
  pname = "libde265";
  inherit base src version;
  inherit (tools) bash coreutils;
  outputs = [ "out" ];
  environment.tools = [ tools.cmake ];
  runtime.libraries = [ ];
  plan = steps.sequence [
    (steps.unpack {
      src = final.src;
      compression = "gzip";
    })
    (steps.cmake {
      name = "libde265";
      inherit (environment) tools libraries env;
      inherit (tools) cmake;
      make = tools.gnumake;
      doCheck = false;
      cmakeFlags = [
        "-DBUILD_SHARED_LIBS=ON"
        "-DENABLE_DECODER=ON"
        "-DENABLE_SDL=OFF"
      ];
    })
    (steps.split "libde265.finalize")
    (outputs.copyArtifacts { outputs = final.outputs; })
    (outputs.relocateText {
      paths = [
        "lib/pkgconfig"
        "lib/cmake/libde265"
      ];
    })
    (outputs.strip { inherit paths; })
    (outputs.rpaths {
      inherit paths;
      libraries = final.runtime.libraries;
    })
    {
      name = "libde265.self-runtime";
      tools = [
        tools.binutils
        tools.patchelf
        tools.python
      ];
      run = ''${tools.python}/bin/python3 -B ${../../../lib/append-self-rpaths.py} "$out" ${
        lib.escapeShellArg (
          builtins.toJSON {
            paths = [ "bin" ];
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
    description = "HEVC decoding library and command-line decoder";
    homepage = "https://github.com/strukturag/libde265";
    license = lib.licenses.lgpl3Plus;
    platforms = [ "x86_64-linux" ];
  };
}

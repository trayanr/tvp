{
  tvp,
  lib,
  base,
  src,
  version,
  imath,
  zstd,
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
  pname = "openexr";
  inherit
    base
    src
    version
    imath
    zstd
    ;
  inherit (tools) bash coreutils;
  outputs = [ "out" ];
  environment = {
    tools = [
      tools.cmake
      tools.pkg-config
    ];
    libraries = [
      final.imath
      final.zstd
    ];
  };
  runtime.libraries = final.environment.libraries;
  plan = steps.sequence [
    (steps.unpack {
      src = final.src;
      compression = "gzip";
    })
    (steps.cmake {
      name = "openexr";
      inherit (environment) tools libraries env;
      inherit (tools) cmake;
      make = tools.gnumake;
      doCheck = false;
      cmakeFlags = [
        "-DBUILD_SHARED_LIBS=ON"
        "-DBUILD_TESTING=OFF"
        "-DImath_DIR=${final.imath}/lib/cmake/Imath"
        # The verified OpenEXR release archive ships both sources.
        "-DOPENEXR_FORCE_INTERNAL_DEFLATE=ON"
        "-DOPENEXR_FORCE_INTERNAL_OPENJPH=ON"
        "-DFETCHCONTENT_FULLY_DISCONNECTED=ON"
      ];
    })
    (steps.split "openexr.finalize")
    (outputs.copyArtifacts { outputs = final.outputs; })
    (outputs.relocateText {
      paths = [
        "lib/pkgconfig"
        "lib/cmake/OpenEXR"
      ];
    })
    (outputs.strip { inherit paths; })
    (outputs.rpaths {
      inherit paths;
      libraries = final.runtime.libraries;
    })
    {
      name = "openexr.bind-self-libraries";
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
    description = "High dynamic range image file format and codec tools";
    homepage = "https://openexr.com/";
    license = lib.licenses.bsd3;
    platforms = [ "x86_64-linux" ];
  };
}

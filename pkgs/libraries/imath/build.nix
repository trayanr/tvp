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
in
{
  pname = "imath";
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
      name = "imath";
      inherit (environment) tools libraries env;
      inherit (tools) cmake;
      make = tools.gnumake;
      doCheck = false;
      cmakeFlags = [
        "-DBUILD_SHARED_LIBS=ON"
        "-DBUILD_TESTING=OFF"
      ];
    })
    (steps.split "imath.finalize")
    (outputs.copyArtifacts { outputs = final.outputs; })
    (outputs.relocateText {
      paths = [
        "lib/pkgconfig"
        "lib/cmake/Imath"
      ];
    })
    (outputs.strip { paths = [ "lib" ]; })
    (outputs.rpaths {
      paths = [ "lib" ];
      libraries = final.runtime.libraries;
    })
    (outputs.checkPaths { paths = [ "lib" ]; })
  ];
  meta = {
    description = "Math types for images and visual effects";
    homepage = "https://imath.readthedocs.io/";
    license = lib.licenses.bsd3;
    platforms = [ "x86_64-linux" ];
  };
}

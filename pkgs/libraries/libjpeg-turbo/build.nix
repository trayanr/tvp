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
  pname = "libjpeg-turbo";
  inherit base src version;
  inherit (tools) bash coreutils;
  environment.tools = [ tools.cmake ];
  runtime.libraries = [ ];
  plan = steps.sequence [
    (steps.unpack { src = final.src; compression = "gzip"; })
    (steps.cmake {
      name = "libjpeg-turbo";
      inherit (environment) tools libraries env;
      inherit (tools) cmake;
      make = tools.gnumake;
      doCheck = false;
      cmakeFlags = [
        "-DENABLE_SHARED=ON"
        "-DENABLE_STATIC=OFF"
        # On x86, the optional assembly requires an additional assembler.
        "-DWITH_SIMD=OFF"
        "-DWITH_TOOLS=OFF"
        "-DWITH_TESTS=OFF"
      ];
    })
    (steps.split "libjpeg-turbo.finalize")
    (outputs.copyArtifacts { })
    (outputs.relocateText {
      paths = [ "lib/pkgconfig/libjpeg.pc" "lib/pkgconfig/libturbojpeg.pc" ];
    })
    (outputs.strip { paths = [ "lib" ]; })
    (outputs.rpaths {
      paths = [ "lib" ];
      libraries = final.runtime.libraries;
    })
    (outputs.checkPaths { paths = [ "lib" ]; })
  ];
  meta = {
    description = "JPEG codec with libjpeg and TurboJPEG interfaces";
    homepage = "https://libjpeg-turbo.org/";
    license = with lib.licenses; [ ijg bsd3 zlib ];
    platforms = [ "x86_64-linux" ];
  };
}

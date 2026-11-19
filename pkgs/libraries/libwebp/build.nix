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
  pname = "libwebp";
  inherit base src version;
  inherit (tools) bash coreutils;
  environment.tools = [ tools.cmake ];
  runtime.libraries = [ ];
  plan = steps.sequence [
    (steps.unpack {
      src = final.src;
      compression = "gzip";
    })
    (steps.cmake {
      name = "libwebp";
      inherit (environment) tools libraries env;
      inherit (tools) cmake;
      make = tools.gnumake;
      doCheck = false;
      cmakeFlags = [
        "-DBUILD_SHARED_LIBS=ON"
        "-DWEBP_BUILD_ANIM_UTILS=OFF"
        "-DWEBP_BUILD_CWEBP=OFF"
        "-DWEBP_BUILD_DWEBP=OFF"
        "-DWEBP_BUILD_GIF2WEBP=OFF"
        "-DWEBP_BUILD_IMG2WEBP=OFF"
        "-DWEBP_BUILD_VWEBP=OFF"
        "-DWEBP_BUILD_WEBPINFO=OFF"
        "-DWEBP_BUILD_WEBPMUX=OFF"
        "-DWEBP_BUILD_EXTRAS=OFF"
      ];
    })
    (steps.split "libwebp.finalize")
    (outputs.copyArtifacts { })
    (outputs.relocateText {
      paths = [
        "lib/pkgconfig/libsharpyuv.pc"
        "lib/pkgconfig/libwebp.pc"
        "lib/pkgconfig/libwebpdecoder.pc"
        "lib/pkgconfig/libwebpdemux.pc"
        "lib/pkgconfig/libwebpmux.pc"
      ];
    })
    (outputs.strip { paths = [ "lib" ]; })
    {
      name = "libwebp.self-runtime";
      tools = [
        tools.binutils
        tools.patchelf
        tools.python
      ];
      run = ''${tools.python}/bin/python3 -B ${../../../lib/append-self-rpaths.py} "$out" ${
        lib.escapeShellArg (
          builtins.toJSON {
            paths = [ "lib" ];
            directories = [ "lib" ];
            readelf = "${tools.binutils}/bin/readelf";
            patchelf = "${tools.patchelf}/bin/patchelf";
          }
        )
      } ${../../../lib/native-output}'';
    }
    (outputs.rpaths {
      paths = [ "lib" ];
      libraries = final.runtime.libraries;
    })
    (outputs.checkPaths { paths = [ "lib" ]; })
  ];
  meta = {
    description = "WebP codec and container libraries";
    homepage = "https://developers.google.com/speed/webp";
    license = lib.licenses.bsd3;
    platforms = [ "x86_64-linux" ];
  };
}

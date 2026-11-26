{
  tvp,
  lib,
  base,
  src,
  version,
  jpeg,
  png,
}:
final:
let
  inherit (tvp.builder.forBase final.base) steps outputs tools;
  environment = final.base.environment final.environment;
  binaryPaths = [
    "bin"
    "lib"
  ];
in
{
  pname = "libwebp";
  inherit
    base
    src
    version
    jpeg
    png
    ;
  inherit (tools) bash coreutils;
  environment = {
    tools = [ tools.cmake ];
    libraries = [
      final.jpeg
      final.png
    ];
  };
  # The PNG command-line tools link zlib directly through CMake's PNG target.
  runtime.libraries = final.environment.libraries ++ [ final.png.specification.zlib ];
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
        "-DCMAKE_REQUIRE_FIND_PACKAGE_JPEG=ON"
        "-DCMAKE_REQUIRE_FIND_PACKAGE_PNG=ON"
        # GIF conversion and animation diagnostics require giflib. TIFF
        # input and the viewer require libtiff and OpenGL/GLUT respectively.
        "-DCMAKE_DISABLE_FIND_PACKAGE_GIF=ON"
        "-DCMAKE_DISABLE_FIND_PACKAGE_TIFF=ON"
        "-DCMAKE_DISABLE_FIND_PACKAGE_OpenGL=ON"
        "-DWEBP_BUILD_ANIM_UTILS=OFF"
        "-DWEBP_BUILD_CWEBP=ON"
        "-DWEBP_BUILD_DWEBP=ON"
        "-DWEBP_BUILD_GIF2WEBP=OFF"
        "-DWEBP_BUILD_IMG2WEBP=ON"
        "-DWEBP_BUILD_VWEBP=OFF"
        "-DWEBP_BUILD_WEBPINFO=ON"
        "-DWEBP_BUILD_WEBPMUX=ON"
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
    (outputs.strip { paths = binaryPaths; })
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
            paths = binaryPaths;
            directories = [ "lib" ];
            readelf = "${tools.binutils}/bin/readelf";
            patchelf = "${tools.patchelf}/bin/patchelf";
          }
        )
      } ${../../../lib/native-output}'';
    }
    (outputs.rpaths {
      paths = binaryPaths;
      libraries = final.runtime.libraries;
    })
    (outputs.checkPaths { paths = binaryPaths; })
  ];
  meta = {
    description = "WebP codec and container libraries and command-line tools";
    homepage = "https://developers.google.com/speed/webp";
    license = lib.licenses.bsd3;
    platforms = [ "x86_64-linux" ];
  };
}

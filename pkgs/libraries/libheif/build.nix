{
  tvp,
  lib,
  base,
  src,
  version,
  brotli,
  libde265,
  jpeg,
  png,
  openjpeg,
  tiff,
  webp,
  x265,
  zlib,
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
  pname = "libheif";
  inherit
    base
    src
    version
    brotli
    libde265
    jpeg
    png
    openjpeg
    tiff
    webp
    x265
    zlib
    ;
  inherit (tools) bash coreutils;
  outputs = [ "out" ];
  environment = {
    tools = [
      tools.cmake
      tools.pkg-config
    ];
    libraries = [
      final.brotli
      final.libde265
      final.jpeg
      final.png
      final.openjpeg
      final.tiff
      final.webp
      final.x265
      final.zlib
    ];
  };
  runtime.libraries = final.environment.libraries;
  plan = steps.sequence [
    (steps.unpack {
      src = final.src;
      compression = "gzip";
    })
    (steps.cmake {
      name = "libheif";
      inherit (environment) tools libraries env;
      inherit (tools) cmake;
      make = tools.gnumake;
      doCheck = false;
      cmakeFlags = [
        "-DBUILD_SHARED_LIBS=ON"
        "-DBUILD_TESTING=OFF"
        "-DBUILD_DOCUMENTATION=OFF"
        "-DCMAKE_PREFIX_PATH=${lib.concatStringsSep ";" (map toString final.environment.libraries)}"
        # Link the selected codecs into libheif itself.
        "-DENABLE_PLUGIN_LOADING=OFF"
        "-DPLUGIN_DIRECTORY="
        "-DWITH_LIBDE265=ON"
        "-DWITH_X265=ON"
        "-DWITH_JPEG_DECODER=ON"
        "-DWITH_JPEG_ENCODER=ON"
        "-DWITH_OpenJPEG_DECODER=ON"
        "-DWITH_OpenJPEG_ENCODER=ON"
        "-DWITH_UNCOMPRESSED_CODEC=ON"
        "-DWITH_AOM_DECODER=OFF"
        "-DWITH_AOM_ENCODER=OFF"
        "-DWITH_X264=OFF"
        "-DWITH_OpenH264_DECODER=OFF"
        "-DWITH_GDK_PIXBUF=OFF"
        "-DWITH_EXAMPLE_HEIF_VIEW=OFF"
      ];
    })
    (steps.split "libheif.finalize")
    (outputs.copyArtifacts { outputs = final.outputs; })
    (outputs.relocateText {
      paths = [
        "lib/pkgconfig"
        "lib/cmake/libheif"
      ];
    })
    (outputs.strip { inherit paths; })
    (outputs.rpaths {
      inherit paths;
      libraries = final.runtime.libraries;
    })
    {
      name = "libheif.self-runtime";
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
    description = "HEIF image library with HEVC decoding and encoding";
    homepage = "https://github.com/strukturag/libheif";
    license = lib.licenses.lgpl3Plus;
    platforms = [ "x86_64-linux" ];
  };
}

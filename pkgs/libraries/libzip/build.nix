{
  tvp,
  lib,
  base,
  src,
  version,
  bzip2,
  openssl,
  xz,
  zlib,
  zstd,
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
  pname = "libzip";
  inherit
    base
    src
    version
    bzip2
    openssl
    xz
    zlib
    zstd
    ;
  inherit (tools) bash coreutils;
  environment = {
    tools = [
      tools.cmake
      tools.pkg-config
    ];
    libraries = [
      final.bzip2
      final.openssl
      final.xz
      final.zlib
      final.zstd
    ];
  };
  runtime.libraries = final.environment.libraries;
  plan = steps.sequence [
    (steps.unpack { src = final.src; })
    (steps.cmake {
      name = "libzip";
      inherit (environment) tools libraries env;
      inherit (tools) cmake;
      make = tools.gnumake;
      doCheck = false;
      cmakeFlags = [
        "-DBUILD_REGRESS=OFF"
        "-DBUILD_OSSFUZZ=OFF"
        "-DBUILD_EXAMPLES=OFF"
        "-DBUILD_DOC=OFF"
        "-DENABLE_COMMONCRYPTO=OFF"
        "-DENABLE_GNUTLS=OFF"
        "-DENABLE_WINDOWS_CRYPTO=OFF"
        "-DENABLE_OPENSSL=ON"
        "-DENABLE_BZIP2=ON"
        "-DENABLE_LZMA=ON"
        "-DENABLE_ZSTD=ON"
        "-DCMAKE_REQUIRE_FIND_PACKAGE_BZip2=ON"
        "-DCMAKE_REQUIRE_FIND_PACKAGE_LibLZMA=ON"
        "-DCMAKE_REQUIRE_FIND_PACKAGE_OpenSSL=ON"
        "-DCMAKE_REQUIRE_FIND_PACKAGE_zstd=ON"
      ];
    })
    (steps.command { environment = { }; } "libzip.license" ''
      install -Dm644 LICENSE "$out/share/licenses/libzip/LICENSE"
    '')
    (steps.split "libzip.finalize")
    (outputs.copyArtifacts { })
    (outputs.relocateText { paths = [ "lib/pkgconfig/libzip.pc" ]; })
    (outputs.strip { paths = binaryPaths; })
    {
      name = "libzip.self-runtime";
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
    (outputs.rpaths {
      paths = binaryPaths;
      libraries = final.runtime.libraries;
    })
    (outputs.development { libraries = final.runtime.libraries; })
    (outputs.checkSymlinks {
      paths = [
        "lib/libzip.so"
        "lib/libzip.so.5"
      ];
    })
    (outputs.checkPaths { paths = binaryPaths; })
  ];
  meta = {
    description = "Library and utilities for manipulating ZIP archives";
    homepage = "https://libzip.org/";
    license = lib.licenses.bsd3;
    platforms = [ "x86_64-linux" ];
  };
}

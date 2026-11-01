{
  lib,
  stdenv,
  fetchurl,
  perl,
  version,
  sha256,
  compileFlags ? [ ],
  mkTests,
}:
stdenv.mkDerivation (
  finalAttrs:
  {
    pname = "libxcrypt";
    inherit version;
    src = fetchurl {
      url = "https://github.com/besser82/libxcrypt/releases/download/v${version}/libxcrypt-${version}.tar.xz";
      inherit sha256;
    };
    nativeBuildInputs = [ perl ];
    enableParallelBuilding = true;
    doCheck = true;
    meta = {
      description = "Extended crypt library";
      homepage = "https://github.com/besser82/libxcrypt/";
      license = lib.licenses.lgpl21Plus;
      platforms = lib.platforms.unix;
    };
    passthru = {
      tvp.deps = {
        inherit perl;
      };
      tvp.cc = stdenv.cc;
      tests = mkTests finalAttrs.finalPackage;
    };
  }
  // lib.optionalAttrs (compileFlags != [ ] && lib.versionAtLeast stdenv.cc.version "15") {
    env.NIX_CFLAGS_COMPILE = lib.concatStringsSep " " compileFlags;
  }
)

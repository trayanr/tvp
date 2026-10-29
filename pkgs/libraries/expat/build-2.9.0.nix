{
  lib,
  stdenv,
  fetchurl,
  cmake,
  ninja,
  patchelf,
  version,
  sha256,
  mkTests,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "expat";
  inherit version;
  src = fetchurl {
    url = "https://github.com/libexpat/libexpat/releases/download/R_${
      lib.replaceStrings [ "." ] [ "_" ] version
    }/expat-${version}.tar.xz";
    inherit sha256;
  };
  nativeBuildInputs = [
    cmake
    ninja
    patchelf
  ];
  cmakeFlags = [
    "-DEXPAT_BUILD_DOCS=OFF"
    "-DEXPAT_BUILD_TESTS=ON"
    "-DEXPAT_BUILD_TOOLS=ON"
    "-DEXPAT_BUILD_EXAMPLES=ON"
  ];
  doCheck = true;
  meta = {
    description = "Streaming XML parser library and xmlwf tool";
    homepage = "https://libexpat.github.io/";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
  };
  passthru = {
    tvp.deps = {
      inherit cmake ninja patchelf;
    };
    tvp.cc = stdenv.cc;
    tests = mkTests finalAttrs.finalPackage;
  };
})

{
  lib,
  stdenv,
  fetchurl,
  pkg-config,
  patchelf,
  version,
  sha256,
  mkTests,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "nghttp2";
  inherit version;
  src = fetchurl {
    url = "https://github.com/nghttp2/nghttp2/releases/download/v${version}/nghttp2-${version}.tar.xz";
    inherit sha256;
  };
  nativeBuildInputs = [
    pkg-config
    patchelf
  ];
  configureFlags = [ "--enable-lib-only" ];
  enableParallelBuilding = true;
  doCheck = true;
  postFixup = ''
    patchelf --shrink-rpath "$out/lib/libnghttp2.so"
  '';
  meta = {
    description = "HTTP/2 C library with HPACK compression";
    homepage = "https://nghttp2.org/";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
  };
  passthru = {
    tvp.deps = {
      inherit pkg-config patchelf;
    };
    tvp.cc = stdenv.cc;
    tests = mkTests finalAttrs.finalPackage;
  };
})

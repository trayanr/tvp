{
  lib,
  stdenv,
  fetchurl,
  patchelf,
  version,
  sha256,
  mkTests,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "alsa-lib";
  inherit version;
  src = fetchurl {
    url = "https://www.alsa-project.org/files/pub/lib/alsa-lib-${version}.tar.bz2";
    inherit sha256;
  };
  nativeBuildInputs = [ patchelf ];
  configureFlags = [ "--disable-python" ];
  enableParallelBuilding = true;
  meta = {
    description = "ALSA userspace sound library";
    homepage = "https://www.alsa-project.org/";
    license = lib.licenses.lgpl21Plus;
    platforms = [ "x86_64-linux" ];
  };
  passthru = {
    tvp.deps = {
      inherit patchelf;
    };
    tvp.cc = stdenv.cc;
    tests = mkTests finalAttrs.finalPackage;
  };
})

{
  lib,
  stdenv,
  fetchurl,
  pkg-config,
  patchelf,
  libice,
  xorgproto,
  xtrans,
  version,
  sha256,
  mkTests,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "libsm";
  inherit version;
  src = fetchurl {
    url = "https://www.x.org/releases/individual/lib/libSM-${version}.tar.xz";
    inherit sha256;
  };
  nativeBuildInputs = [
    pkg-config
    patchelf
  ];
  propagatedBuildInputs = [
    libice
    xorgproto
  ];
  preConfigure = ''
    export PKG_CONFIG_PATH="${libice}/lib/pkgconfig:${libice}/share/pkgconfig:${xorgproto}/lib/pkgconfig:${xorgproto}/share/pkgconfig:${xtrans}/lib/pkgconfig:${xtrans}/share/pkgconfig"

  '';
  configureFlags = [ "--without-libuuid" ];
  enableParallelBuilding = true;
  doCheck = true;
  meta = {
    description = "libSM X.Org client library";
    homepage = "https://www.x.org/";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
  };
  passthru = {
    tvp.deps = {
      inherit
        pkg-config
        patchelf
        libice
        xorgproto
        xtrans
        ;
    };
    tvp.cc = stdenv.cc;
    tests = mkTests finalAttrs.finalPackage;
  };
})

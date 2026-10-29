{
  lib,
  stdenv,
  fetchurl,
  pkg-config,
  patchelf,
  libsm,
  libice,
  libx11,
  xorgproto,
  xtrans,
  libxcb,
  libxau,
  libxdmcp,
  version,
  sha256,
  mkTests,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "libxt";
  inherit version;
  src = fetchurl {
    url = "https://www.x.org/releases/individual/lib/libXt-${version}.tar.xz";
    inherit sha256;
  };
  nativeBuildInputs = [
    pkg-config
    patchelf
  ];
  propagatedBuildInputs = [
    libsm
    libice
    libx11
    xorgproto
  ];
  preConfigure = ''
    export PKG_CONFIG_PATH="${libsm}/lib/pkgconfig:${libsm}/share/pkgconfig:${libice}/lib/pkgconfig:${libice}/share/pkgconfig:${libx11}/lib/pkgconfig:${libx11}/share/pkgconfig:${xorgproto}/lib/pkgconfig:${xorgproto}/share/pkgconfig:${xtrans}/lib/pkgconfig:${xtrans}/share/pkgconfig:${libxcb}/lib/pkgconfig:${libxcb}/share/pkgconfig:${libxau}/lib/pkgconfig:${libxau}/share/pkgconfig:${libxdmcp}/lib/pkgconfig:${libxdmcp}/share/pkgconfig"

  '';

  enableParallelBuilding = true;
  doCheck = true;
  meta = {
    description = "libXt X.Org client library";
    homepage = "https://www.x.org/";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
  };
  passthru = {
    tvp.deps = {
      inherit
        pkg-config
        patchelf
        libsm
        libice
        libx11
        xorgproto
        xtrans
        libxcb
        libxau
        libxdmcp
        ;
    };
    tvp.cc = stdenv.cc;
    tests = mkTests finalAttrs.finalPackage;
  };
})

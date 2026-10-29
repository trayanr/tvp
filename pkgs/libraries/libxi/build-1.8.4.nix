{
  lib,
  stdenv,
  fetchurl,
  pkg-config,
  patchelf,
  libx11,
  libxext,
  libxfixes,
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
  pname = "libxi";
  inherit version;
  src = fetchurl {
    url = "https://www.x.org/releases/individual/lib/libXi-${version}.tar.xz";
    inherit sha256;
  };
  nativeBuildInputs = [
    pkg-config
    patchelf
  ];
  propagatedBuildInputs = [
    libx11
    libxext
    libxfixes
    xorgproto
  ];
  preConfigure = ''
    export PKG_CONFIG_PATH="${libx11}/lib/pkgconfig:${libx11}/share/pkgconfig:${libxext}/lib/pkgconfig:${libxext}/share/pkgconfig:${libxfixes}/lib/pkgconfig:${libxfixes}/share/pkgconfig:${xorgproto}/lib/pkgconfig:${xorgproto}/share/pkgconfig:${xtrans}/lib/pkgconfig:${xtrans}/share/pkgconfig:${libxcb}/lib/pkgconfig:${libxcb}/share/pkgconfig:${libxau}/lib/pkgconfig:${libxau}/share/pkgconfig:${libxdmcp}/lib/pkgconfig:${libxdmcp}/share/pkgconfig"

  '';

  enableParallelBuilding = true;
  doCheck = true;
  meta = {
    description = "libXi X.Org client library";
    homepage = "https://www.x.org/";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
  };
  passthru = {
    tvp.deps = {
      inherit
        pkg-config
        patchelf
        libx11
        libxext
        libxfixes
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

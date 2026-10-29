{
  lib,
  stdenv,
  fetchurl,
  pkg-config,
  patchelf,
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
  pname = "libx11";
  inherit version;
  src = fetchurl {
    url = "https://www.x.org/releases/individual/lib/libX11-${version}.tar.xz";
    inherit sha256;
  };
  nativeBuildInputs = [
    pkg-config
    patchelf
  ];
  propagatedBuildInputs = [
    xorgproto
    xtrans
    libxcb
  ];
  preConfigure = ''
    export PKG_CONFIG_PATH="${xorgproto}/lib/pkgconfig:${xorgproto}/share/pkgconfig:${xtrans}/lib/pkgconfig:${xtrans}/share/pkgconfig:${libxcb}/lib/pkgconfig:${libxcb}/share/pkgconfig:${libxau}/lib/pkgconfig:${libxau}/share/pkgconfig:${libxdmcp}/lib/pkgconfig:${libxdmcp}/share/pkgconfig"

  '';

  enableParallelBuilding = true;
  doCheck = true;
  meta = {
    description = "libX11 X.Org client library";
    homepage = "https://www.x.org/";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
  };
  passthru = {
    tvp.deps = {
      inherit
        pkg-config
        patchelf
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

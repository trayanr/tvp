{
  lib,
  stdenv,
  fetchurl,
  pkg-config,
  patchelf,
  xorgproto,
  xtrans,
  version,
  sha256,
  mkTests,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "libice";
  inherit version;
  src = fetchurl {
    url = "https://www.x.org/releases/individual/lib/libICE-${version}.tar.xz";
    inherit sha256;
  };
  nativeBuildInputs = [
    pkg-config
    patchelf
  ];
  propagatedBuildInputs = [
    xorgproto
    xtrans
  ];
  preConfigure = ''
    export PKG_CONFIG_PATH="${xorgproto}/lib/pkgconfig:${xorgproto}/share/pkgconfig:${xtrans}/lib/pkgconfig:${xtrans}/share/pkgconfig"

  '';

  enableParallelBuilding = true;
  doCheck = true;
  meta = {
    description = "libICE X.Org client library";
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
        ;
    };
    tvp.cc = stdenv.cc;
    tests = mkTests finalAttrs.finalPackage;
  };
})

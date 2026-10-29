{
  lib,
  stdenv,
  fetchurl,
  pkg-config,
  patchelf,
  python,
  xcb-proto,
  libxau,
  libxdmcp,
  xorgproto,
  version,
  sha256,
  mkTests,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "libxcb";
  inherit version;
  src = fetchurl {
    url = "https://xcb.freedesktop.org/dist/libxcb-${version}.tar.xz";
    inherit sha256;
  };
  nativeBuildInputs = [
    pkg-config
    patchelf
    python
    xcb-proto
  ];
  propagatedBuildInputs = [
    libxau
    libxdmcp
  ];
  preConfigure = ''
    export PKG_CONFIG_PATH="${xcb-proto}/lib/pkgconfig:${xcb-proto}/share/pkgconfig:${libxau}/lib/pkgconfig:${libxau}/share/pkgconfig:${libxdmcp}/lib/pkgconfig:${libxdmcp}/share/pkgconfig:${xorgproto}/lib/pkgconfig:${xorgproto}/share/pkgconfig"
    export PYTHONPATH="${xcb-proto}/lib/python3.12/site-packages"
    export PYTHON="${python}/bin/python3"
  '';

  enableParallelBuilding = true;
  doCheck = true;
  meta = {
    description = "libxcb X.Org client library";
    homepage = "https://www.x.org/";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
  };
  passthru = {
    tvp.deps = {
      inherit
        pkg-config
        patchelf
        python
        xcb-proto
        libxau
        libxdmcp
        xorgproto
        ;
    };
    tvp.cc = stdenv.cc;
    tests = mkTests finalAttrs.finalPackage;
  };
})

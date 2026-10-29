{
  lib,
  stdenv,
  fetchurl,
  meson,
  ninja,
  python,
  pkg-config,
  gperf,
  freetype,
  expat,
  patchelf,
  version,
  sha256,
  mkTests,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "fontconfig";
  inherit version;
  src = fetchurl {
    url = "https://gitlab.freedesktop.org/api/v4/projects/890/packages/generic/fontconfig/${version}/fontconfig-${version}.tar.xz";
    inherit sha256;
  };
  nativeBuildInputs = [
    meson
    ninja
    python
    pkg-config
    gperf
    patchelf
  ];
  buildInputs = [
    freetype
    expat
  ];
  preConfigure = ''
    patchShebangs .
    export PKG_CONFIG_PATH='${freetype}/lib/pkgconfig:${expat}/lib/pkgconfig'
  '';
  mesonFlags = [
    "-Ddoc=disabled"
    "-Dnls=disabled"
    "-Dtests=enabled"
    "-Dtests-bwrap=disabled"
    "-Dtests-external-fonts=disabled"
    "-Dtools=enabled"
    "-Dcache-build=disabled"
    "-Dxml-backend=expat"
    "-Dfontations=disabled"
  ];
  doCheck = true;
  meta = {
    description = "Font discovery and configuration library";
    homepage = "https://fontconfig.org/";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
  };
  passthru = {
    tvp.deps = {
      inherit
        meson
        ninja
        python
        pkg-config
        gperf
        freetype
        expat
        patchelf
        ;
    };
    tvp.cc = stdenv.cc;
    tests = mkTests finalAttrs.finalPackage;
  };
})

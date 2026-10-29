{
  lib,
  stdenv,
  fetchurl,
  pkg-config,
  patchelf,
  xorgproto,
  version,
  sha256,
  mkTests,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "libxdmcp";
  inherit version;
  src = fetchurl {
    url = "https://www.x.org/releases/individual/lib/libXdmcp-${version}.tar.xz";
    inherit sha256;
  };
  nativeBuildInputs = [
    pkg-config
    patchelf
  ];
  propagatedBuildInputs = [ xorgproto ];
  preConfigure = ''
    export PKG_CONFIG_PATH="${xorgproto}/lib/pkgconfig:${xorgproto}/share/pkgconfig"

  '';

  enableParallelBuilding = true;
  doCheck = true;
  meta = {
    description = "libXdmcp X.Org client library";
    homepage = "https://www.x.org/";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
  };
  passthru = {
    tvp.deps = {
      inherit pkg-config patchelf xorgproto;
    };
    tvp.cc = stdenv.cc;
    tests = mkTests finalAttrs.finalPackage;
  };
})

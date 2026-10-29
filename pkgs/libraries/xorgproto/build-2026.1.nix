{
  lib,
  stdenv,
  fetchurl,
  pkg-config,
  version,
  sha256,
  mkTests,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "xorgproto";
  inherit version;
  src = fetchurl {
    url = "https://www.x.org/releases/individual/proto/xorgproto-${version}.tar.xz";
    inherit sha256;
  };
  nativeBuildInputs = [ pkg-config ];
  propagatedBuildInputs = [ ];
  preConfigure = ''
    export PKG_CONFIG_PATH=""

  '';

  enableParallelBuilding = true;
  doCheck = true;
  meta = {
    description = "X.Org protocol headers";
    homepage = "https://www.x.org/";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
  };
  passthru = {
    tvp.deps = {
      inherit pkg-config;
    };
    tvp.cc = stdenv.cc;
    tests = mkTests finalAttrs.finalPackage;
  };
})

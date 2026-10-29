{
  lib,
  stdenv,
  fetchurl,
  pkg-config,
  python,
  version,
  sha256,
  mkTests,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "xcb-proto";
  inherit version;
  src = fetchurl {
    url = "https://xcb.freedesktop.org/dist/xcb-proto-${version}.tar.xz";
    inherit sha256;
  };
  nativeBuildInputs = [
    pkg-config
    python
  ];
  propagatedBuildInputs = [ ];
  preConfigure = ''
    export PKG_CONFIG_PATH=""

    export PYTHON="${python}/bin/python3"
  '';

  enableParallelBuilding = true;
  doCheck = true;
  meta = {
    description = "XCB protocol XML and Python code-generation library";
    homepage = "https://www.x.org/";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
  };
  passthru = {
    tvp.deps = {
      inherit pkg-config python;
    };
    tvp.cc = stdenv.cc;
    tests = mkTests finalAttrs.finalPackage;
  };
})

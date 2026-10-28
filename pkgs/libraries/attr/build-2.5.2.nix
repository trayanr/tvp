# Serves 2.5.2 onwards.
{
  lib,
  stdenv,
  fetchurl,
  version,
  sha256,
  mkTests,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "attr";
  inherit version;
  src = fetchurl {
    url = "https://download.savannah.nongnu.org/releases/attr/attr-${version}.tar.gz";
    inherit sha256;
  };
  buildInputs = [ ];
  enableParallelBuilding = true;
  configureFlags = [ ];

  meta = {
    description = "Extended attribute utilities and library";
    license = lib.licenses.lgpl21Plus;
    platforms = lib.platforms.unix;
  };
  passthru = {
    tvp.deps = { };
    tvp.cc = stdenv.cc;
    tests = mkTests finalAttrs.finalPackage;
  };
})

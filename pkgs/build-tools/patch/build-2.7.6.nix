# Serves 2.7.6 onwards.
{
  lib,
  stdenv,
  fetchurl,
  version,
  sha256,
  mkTests,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "patch";
  inherit version;
  src = fetchurl {
    url = "https://mirrors.kernel.org/gnu/patch/patch-${version}.tar.xz";
    inherit sha256;
  };
  buildInputs = [ ];
  enableParallelBuilding = true;
  configureFlags = [ ];

  meta = {
    description = "GNU patch application utility";
    license = lib.licenses.gpl3Plus;
    platforms = lib.platforms.unix;
  };
  passthru = {
    tvp.deps = { };
    tvp.cc = stdenv.cc;
    tests = mkTests finalAttrs.finalPackage;
  };
})

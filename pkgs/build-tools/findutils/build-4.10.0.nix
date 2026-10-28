# Serves 4.10.0 onwards.
{
  lib,
  stdenv,
  fetchurl,
  coreutils,
  version,
  sha256,
  mkTests,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "findutils";
  inherit version;
  src = fetchurl {
    url = "https://mirrors.kernel.org/gnu/findutils/findutils-${version}.tar.xz";
    inherit sha256;
  };
  buildInputs = [ ];
  # updatedb records the sort program found during configure.
  nativeBuildInputs = [ coreutils ];
  enableParallelBuilding = true;
  configureFlags = [ ];

  meta = {
    description = "GNU file searching utilities";
    license = lib.licenses.gpl3Plus;
    platforms = lib.platforms.unix;
  };
  passthru = {
    tvp.deps = {
      inherit coreutils;
    };
    tvp.cc = stdenv.cc;
    tests = mkTests finalAttrs.finalPackage;
  };
})

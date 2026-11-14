# Serves 1.13 onwards.
{
  lib,
  stdenv,
  fetchurl,
  gnugrep,
  version,
  sha256,
  mkTests,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "gzip";
  inherit version;
  src = fetchurl {
    url = "https://mirrors.kernel.org/gnu/gzip/gzip-${version}.tar.xz";
    inherit sha256;
  };
  buildInputs = [ ];
  # zgrep records the grep program found during configure.
  nativeBuildInputs = [ gnugrep ];
  enableParallelBuilding = true;
  configureFlags = [ ];

  meta = {
    description = "GNU gzip compression utilities";
    license = lib.licenses.gpl3Plus;
    platforms = lib.platforms.unix;
  };
  passthru = {
    tvp.deps = {
      inherit gnugrep;
    };
    tvp.cc = stdenv.cc;
    tests = mkTests finalAttrs.finalPackage;
  };
})

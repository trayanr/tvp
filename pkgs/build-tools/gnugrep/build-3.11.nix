# Serves 3.11 onwards.
{
  lib,
  stdenv,
  fetchurl,
  pcre2,
  version,
  sha256,
  mkTests,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "gnugrep";
  inherit version;
  src = fetchurl {
    url = "https://mirrors.kernel.org/gnu/grep/grep-${version}.tar.xz";
    inherit sha256;
  };
  buildInputs = [ pcre2 ];
  enableParallelBuilding = true;
  configureFlags = [ ];

  meta = {
    description = "GNU pattern matching utilities";
    license = lib.licenses.gpl3Plus;
    platforms = lib.platforms.unix;
  };
  passthru = {
    tvp.deps = {
      inherit pcre2;
    };
    tvp.cc = stdenv.cc;
    tests = mkTests finalAttrs.finalPackage;
  };
})

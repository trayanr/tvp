# Serves 10.44 onwards.
{
  lib,
  stdenv,
  fetchurl,
  version,
  sha256,
  mkTests,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "pcre2";
  inherit version;
  src = fetchurl {
    url = "https://github.com/PCRE2Project/pcre2/releases/download/pcre2-${version}/pcre2-${version}.tar.bz2";
    inherit sha256;
  };
  buildInputs = [ ];
  enableParallelBuilding = true;
  configureFlags = [
    "--enable-pcre2-16"
    "--enable-pcre2-32"
    "--enable-jit"
    "--enable-unicode"
  ];

  meta = {
    description = "Perl-compatible regular expressions library";
    license = lib.licenses.bsd3;
    platforms = lib.platforms.unix;
  };
  passthru = {
    tvp.deps = { };
    tvp.cc = stdenv.cc;
    tests = mkTests finalAttrs.finalPackage;
  };
})

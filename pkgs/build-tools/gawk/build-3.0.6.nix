# Gawk 3.x predates Readline and GMP/MPFR support; none are build inputs.
{
  lib,
  stdenv,
  fetchurl,
  version,
  sha256,
  hardeningDisable ? [ ],
  archiveExt ? "tar.bz2",
  license ? lib.licenses.gpl3Plus,
  mkTests,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "gawk";
  inherit version hardeningDisable;
  src = fetchurl {
    url = "https://mirrors.kernel.org/gnu/gawk/gawk-${version}.${archiveExt}";
    inherit sha256;
  };
  buildInputs = [ ];
  enableParallelBuilding = true;
  configureFlags = [ ];

  meta = {
    description = "GNU AWK";
    inherit license;
    platforms = lib.platforms.unix;
  };
  passthru = {
    tvp.deps = { };
    tvp.features.bignum = false;
    tvp.cc = stdenv.cc;
    tests = mkTests finalAttrs.finalPackage;
  };
})

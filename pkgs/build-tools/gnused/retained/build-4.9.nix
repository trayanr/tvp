# Serves 4.9 onwards.
{
  lib,
  stdenv,
  fetchurl,
  acl,
  version,
  sha256,
  mkTests,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "gnused";
  inherit version;
  src = fetchurl {
    url = "https://mirrors.kernel.org/gnu/sed/sed-${version}.tar.xz";
    inherit sha256;
  };
  buildInputs = [ acl ];
  enableParallelBuilding = true;
  configureFlags = [ ];

  meta = {
    description = "GNU stream editor";
    license = lib.licenses.gpl3Plus;
    platforms = lib.platforms.unix;
  };
  passthru = {
    tvp.deps = {
      inherit acl;
    };
    tvp.cc = stdenv.cc;
    tests = mkTests finalAttrs.finalPackage;
  };
})

# Serves 1.35 onwards.
{
  lib,
  stdenv,
  fetchurl,
  acl,
  attr,
  version,
  sha256,
  mkTests,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "gnutar";
  inherit version;
  src = fetchurl {
    url = "https://mirrors.kernel.org/gnu/tar/tar-${version}.tar.xz";
    inherit sha256;
  };
  buildInputs = [
    acl
    attr
  ];
  enableParallelBuilding = true;
  configureFlags = [ ];

  meta = {
    description = "GNU archive utility";
    license = lib.licenses.gpl3Plus;
    platforms = lib.platforms.unix;
  };
  passthru = {
    tvp.deps = {
      inherit acl attr;
    };
    tvp.cc = stdenv.cc;
    tests = mkTests finalAttrs.finalPackage;
  };
})

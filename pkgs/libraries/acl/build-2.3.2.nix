# Serves 2.3.2 onwards.
{
  lib,
  stdenv,
  fetchurl,
  attr,
  version,
  sha256,
  mkTests,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "acl";
  inherit version;
  src = fetchurl {
    url = "https://download.savannah.nongnu.org/releases/acl/acl-${version}.tar.gz";
    inherit sha256;
  };
  propagatedBuildInputs = [ attr ];
  enableParallelBuilding = true;
  configureFlags = [ ];

  meta = {
    description = "POSIX access control list utilities and library";
    license = lib.licenses.lgpl21Plus;
    platforms = lib.platforms.unix;
  };
  passthru = {
    tvp.deps = {
      inherit attr;
    };
    tvp.cc = stdenv.cc;
    tests = mkTests finalAttrs.finalPackage;
  };
})

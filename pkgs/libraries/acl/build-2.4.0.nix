# Serves 2.4.0 onwards.
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
  # configure and perm_copy_* still require attr/error_context.h. Installed
  # public ACL headers only forward-declare error_context; libacl no longer
  # links libattr. Consumers defining that optional struct need explicit Attr.
  buildInputs = [ attr ];
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

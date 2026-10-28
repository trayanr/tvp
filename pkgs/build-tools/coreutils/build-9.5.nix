# Serves 9.5 onwards.
{
  lib,
  stdenv,
  fetchurl,
  gmp,
  acl,
  version,
  sha256,
  mkTests,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "coreutils";
  inherit version;
  src = fetchurl {
    url = "https://mirrors.kernel.org/gnu/coreutils/coreutils-${version}.tar.xz";
    inherit sha256;
  };
  buildInputs = [
    gmp
    acl
  ];
  enableParallelBuilding = true;
  configureFlags = [
    "--with-gmp"
    "--enable-acl"
    "--without-selinux"
  ];
  env.FORCE_UNSAFE_CONFIGURE = "1";

  meta = {
    description = "GNU core utilities";
    license = lib.licenses.gpl3Plus;
    platforms = lib.platforms.unix;
  };
  passthru = {
    tvp.deps = {
      inherit gmp acl;
    };
    tvp.cc = stdenv.cc;
    tests = mkTests finalAttrs.finalPackage;
  };
})

# Serves 3.10 onwards.
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
  pname = "diffutils";
  inherit version;
  src = fetchurl {
    url = "https://mirrors.kernel.org/gnu/diffutils/diffutils-${version}.tar.xz";
    inherit sha256;
  };
  buildInputs = [ ];
  # diff -l invokes pr; configure records its absolute path.
  nativeBuildInputs = [ coreutils ];
  enableParallelBuilding = true;
  configureFlags = [ ];

  meta = {
    description = "GNU file comparison utilities";
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

# Serves 5.0.0 onwards.
{
  lib,
  stdenv,
  fetchurl,

  version,
  sha256,

  # Supplied by default.nix. A fork that drops this argument fails to evaluate.
  mkTests,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "xz";
  inherit version;

  src = fetchurl {
    url = "https://tukaani.org/xz/xz-${version}.tar.gz";
    inherit sha256;
  };

  meta = {
    description = "XZ Utils — general-purpose data compression with the LZMA2 algorithm";
    homepage = "https://tukaani.org/xz/";
    license = lib.licenses.gpl2Plus;
    platforms = lib.platforms.unix;
  };

  passthru = {
    inherit version;
    tvp.deps = { };
    tvp.cc = stdenv.cc;

    tvp.features = {
      threaded = lib.versionAtLeast version "5.2.0";
    };

    tests = mkTests finalAttrs.finalPackage;
  };
})

# Serves 5.8.4 onwards: release tarballs use the official GitHub releases URL
# because the historical tukaani.org/xz URL does not provide this release.
# Run the upstream check target for these releases.
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
    url = "https://github.com/tukaani-project/xz/releases/download/v${version}/xz-${version}.tar.gz";
    inherit sha256;
  };

  doCheck = true;

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

# Serves 1.2.3 onwards.
#
# zlib's `configure` is hand-written, not autoconf: it accepts --prefix,
# --libdir, --includedir, --shared and --static and rejects anything else, so
# the stdenv must not add its usual flags.
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
  pname = "zlib";
  inherit version;

  # zlib.net serves only current releases; fossils/ is upstream's own archive of
  # every tarball it has published, and covers the whole line from one pattern.
  src = fetchurl {
    url = "https://zlib.net/fossils/zlib-${version}.tar.gz";
    inherit sha256;
  };

  # --build/--host are autoconf spellings that this configure rejects outright.
  configurePlatforms = [ ];

  configureFlags = [ "--shared" ];

  meta = {
    description = "Lossless data-compression library implementing the DEFLATE algorithm";
    homepage = "https://zlib.net/";
    license = lib.licenses.zlib;
    platforms = lib.platforms.unix;
  };

  passthru = {
    inherit version;
    tvp.deps = { };

    # zlib.pc arrived at 1.2.3.1. Before 1.2.3.3 `--shared` selected shared
    # *instead of* static, so those releases ship no libz.a; from 1.2.3.3 the
    # configure builds both and --shared is a no-op.
    tvp.features = {
      pkgConfig = lib.versionAtLeast version "1.2.3.1";
      static = lib.versionAtLeast version "1.2.3.3";
    };

    tests = mkTests finalAttrs.finalPackage;
  };
})

# Serves 3.0.9 onwards.
{
  lib,
  stdenv,
  fetchurl,

  version,
  sha256,

  # 3.6.0 is the one release whose ffi_get_version() disagrees with its tarball
  # name; 3.7.0 closed the class by deriving it from AC_PACKAGE_VERSION.
  reportedVersion ? version,

  # Supplied by default.nix. A fork that drops this argument fails to evaluate.
  mkTests,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "libffi";
  inherit version;

  # sourceware carries the line up to 3.4.3 and stops; GitHub releases start at
  # 3.3. The overlap is byte-identical.
  src = fetchurl {
    urls = [
      "https://sourceware.org/pub/libffi/libffi-${version}.tar.gz"
      "https://github.com/libffi/libffi/releases/download/v${version}/libffi-${version}.tar.gz"
    ];
    inherit sha256;
  };

  meta = {
    description = "Foreign function interface library";
    homepage = "https://sourceware.org/libffi/";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };

  passthru = {
    inherit version;
    tvp.deps = { };
    tvp.cc = stdenv.cc;
    tvp.reportedVersion = reportedVersion;

    tvp.features = {
      headersInIncludedir = lib.versionAtLeast version "3.3";
      variadic = lib.versionAtLeast version "3.0.11";
      versionFunction = lib.versionAtLeast version "3.5.0";
    };

    tests = mkTests finalAttrs.finalPackage;
  };
})

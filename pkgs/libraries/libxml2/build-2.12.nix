# Serves 2.12 onwards.
{
  lib,
  stdenv,
  fetchurl,

  zlib,
  xz,

  version,
  sha256,

  # Supplied by default.nix. A fork that drops this argument fails to evaluate.
  mkTests,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "libxml2";
  inherit version;

  src = fetchurl {
    url = "https://download.gnome.org/sources/libxml2/${lib.versions.majorMinor version}/libxml2-${version}.tar.xz";
    inherit sha256;
  };

  buildInputs = [
    zlib
    xz
  ];

  # The Python bindings are a separate artifact with their own interpreter
  # dependency; TVP packages the library.
  configureFlags = [
    "--without-python"
    "--with-zlib=${lib.getDev zlib}"
    "--with-lzma=${lib.getDev xz}"
  ];

  meta = {
    description = "XML parsing library for C";
    homepage = "https://gitlab.gnome.org/GNOME/libxml2";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };

  passthru = {
    inherit version;
    tvp.deps = {
      inherit zlib xz;
    };

    tests = mkTests finalAttrs.finalPackage;
  };
})

# Serves 2.15.4 onwards. The release's generated configure script requires
# pkg-config even when dependency paths are supplied explicitly.
{
  lib,
  stdenv,
  fetchurl,

  zlib,
  pkg-config,

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

  nativeBuildInputs = [ pkg-config ];

  buildInputs = [
    zlib
  ];

  # The Python bindings are a separate artifact with their own interpreter
  # dependency; TVP packages the library.
  configureFlags = [
    "--without-python"
    "--with-zlib=${lib.getDev zlib}"
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
      inherit zlib pkg-config;
    };

    tvp.features = {
      xpath = true;
    };

    tests = mkTests finalAttrs.finalPackage;
  };
})

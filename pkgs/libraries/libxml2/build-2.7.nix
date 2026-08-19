# Serves 2.7.4 to 2.7.8 — the generation before libxml2 had LZMA support.
# --with-lzma is unrecognized here, so declaring xz would put it in the graph
# and leave it out of the artifact.
{
  lib,
  stdenv,
  fetchurl,

  zlib,

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
      inherit zlib;
    };

    tvp.features = {
      # xmllint gained --xpath at 2.7.7, measured against its own --help.
      xpath = lib.versionAtLeast version "2.7.7";
    };

    tests = mkTests finalAttrs.finalPackage;
  };
})

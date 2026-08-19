# Serves 0.0.1 onwards.
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
  pname = "libyaml";
  inherit version;

  src = fetchurl {
    url = "https://pyyaml.org/download/libyaml/yaml-${version}.tar.gz";
    inherit sha256;
  };

  meta = {
    description = "C library for parsing and emitting YAML";
    homepage = "https://pyyaml.org/wiki/LibYAML";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };

  passthru = {
    inherit version;
    tvp.deps = { };
    tvp.cc = stdenv.cc;

    tvp.features = {
      document = lib.versionAtLeast version "0.1.1";
      pkgConfig = lib.versionAtLeast version "0.1.4";
    };

    tests = mkTests finalAttrs.finalPackage;
  };
})

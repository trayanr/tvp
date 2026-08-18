# Serves 0.29.2 onwards.
#
# --with-internal-glib is not a preference: pkg-config's only dependency is
# glib, and glib's build needs pkg-config. Upstream ships a glib copy precisely
# to break that cycle, and every distribution uses it.
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
  pname = "pkg-config";
  inherit version;

  src = fetchurl {
    url = "https://pkg-config.freedesktop.org/releases/pkg-config-${version}.tar.gz";
    inherit sha256;
  };

  configureFlags = [ "--with-internal-glib" ];

  meta = {
    description = "Tool that returns compiler and linker flags for installed libraries";
    homepage = "https://www.freedesktop.org/wiki/Software/pkg-config/";
    license = lib.licenses.gpl2Plus;
    platforms = lib.platforms.unix;
    mainProgram = "pkg-config";
  };

  passthru = {
    inherit version;
    tvp.deps = { };

    tests = mkTests finalAttrs.finalPackage;
  };
})

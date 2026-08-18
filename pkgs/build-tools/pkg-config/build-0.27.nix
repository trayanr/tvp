# Serves 0.27 only.
#
# 0.27 bundles glib 2.32.3, whose configure aborts unless msgfmt is on PATH;
# the 2.32.4 shipped with 0.27.1 dropped that requirement.
#
# The bundled glib calls strftime with a non-literal format, and its own
# -Werror=format-nonliteral turns modern gcc's stricter analysis into a build
# failure. Upstream fixed it in the glib shipped with 0.29.2, by scoping a
# diagnostic pragma around g_date_strftime; the same change is applied here to
# the releases that predate it.
#
# --with-internal-glib is not a preference: pkg-config's only dependency is
# glib, and glib's build needs pkg-config. Upstream ships a glib copy precisely
# to break that cycle, and every distribution uses it.
{
  lib,
  stdenv,
  fetchurl,
  gettext,

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

  # g_date_strftime is the last function in the file, so the pop belongs at EOF
  # — which is exactly where 0.29.2 puts it.
  postPatch = ''
    sed -z -i 's|\ngsize[ \t]*\ng_date_strftime |\n#pragma GCC diagnostic push\n#pragma GCC diagnostic ignored "-Wformat-nonliteral"\n\ngsize\ng_date_strftime |' glib/glib/gdate.c
    printf '\n#pragma GCC diagnostic pop\n' >> glib/glib/gdate.c
  '';

  nativeBuildInputs = [ gettext ];

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
    tvp.deps = {
      inherit gettext;
    };

    tests = mkTests finalAttrs.finalPackage;
  };
})

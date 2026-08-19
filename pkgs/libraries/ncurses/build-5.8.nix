# Serves 5.8 to 5.9 — the two releases with --enable-pc-files but no
# --with-pkg-config-libdir, so the .pc files land in the configured libdir and
# there is nothing to create before configure runs.
#
# --enable-widec is a uniform TVP choice, not upstream's default before 6.6:
# a narrow build cannot represent UTF-8, and every consumer of a modern ncurses
# links the wide library. It renames everything to the "w" variants, so the
# pkg-config name is ncursesw throughout.
{
  lib,
  stdenv,
  fetchurl,

  # configure refuses --enable-pc-files unless pkg-config is on PATH.
  pkg-config,

  version,
  sha256,

  hardeningDisable ? [ ],

  # Supplied by default.nix. A fork that drops this argument fails to evaluate.
  mkTests,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "ncurses";
  inherit version;

  src = fetchurl {
    url = "https://ftp.gnu.org/gnu/ncurses/ncurses-${version}.tar.gz";
    inherit sha256;
  };

  nativeBuildInputs = [ pkg-config ];

  inherit hardeningDisable;

  # This generation derives the .pc directory from the pkg-config binary's own
  # prefix and installs nothing unless it exists. --with-pkg-config-libdir, which
  # 6.0 added for this, is not available yet; configure reads the environment
  # instead and says so.
  env.PKG_CONFIG_LIBDIR = "${placeholder "out"}/lib/pkgconfig";

  preConfigure = ''
    mkdir -p "$out/lib/pkgconfig"
  '';

  configureFlags = [
    "--with-shared"
    "--enable-widec"
    "--without-debug"
    "--without-tests"
    "--enable-pc-files"
  ];

  meta = {
    description = "Free software emulation of curses";
    homepage = "https://invisible-island.net/ncurses/";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };

  passthru = {
    inherit version;
    tvp.deps = {
      inherit pkg-config;
    };
    tvp.cc = stdenv.cc;

    tvp.features = {
      widec = true;
      libName = "ncursesw";
      pkgConfig = true;
      cxx = true;
    };

    tests = mkTests finalAttrs.finalPackage;
  };
})

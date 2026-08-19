# Serves 6.0 onwards.
#
# --enable-widec is a uniform TVP choice, not upstream's default before 6.6:
# a narrow build cannot represent UTF-8, and every consumer of a modern ncurses
# links the wide library. It renames everything to the "w" variants, so the
# pkg-config name is ncursesw throughout.
{
  lib,
  stdenv,
  fetchurl,

  # 6.3 and earlier refuse --enable-pc-files unless pkg-config is on PATH at
  # configure time; 6.4 onwards tolerate its absence.
  pkg-config,

  version,
  sha256,

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

  # 6.3 validates --with-pkg-config-libdir by checking the directory exists.
  preConfigure = ''
    mkdir -p "$out/lib/pkgconfig"
  '';

  configureFlags = [
    "--with-shared"
    "--enable-widec"
    "--without-debug"
    "--enable-pc-files"
    "--with-pkg-config-libdir=${placeholder "out"}/lib/pkgconfig"
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

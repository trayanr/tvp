# Serves 8.0 onwards.
{
  lib,
  stdenv,
  fetchurl,

  openssl,
  zlib,
  libxml2,
  readline,
  ncurses,
  sqlite,
  pkg-config,

  version,
  sha256,

  # Supplied by default.nix. A fork that drops this argument fails to evaluate.
  mkTests,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "php";
  inherit version;

  # Releases before 5.3.27 are served only by museum.php.net, whose path
  # carries a bare major digit and therefore needs its own builder.
  src = fetchurl {
    url = "https://www.php.net/distributions/php-${version}.tar.gz";
    inherit sha256;
  };

  nativeBuildInputs = [ pkg-config ];

  buildInputs = [
    openssl
    zlib
    libxml2
    readline
    ncurses
    sqlite
  ];

  # nixpkgs' pkg-config carries a setup hook that builds PKG_CONFIG_PATH out of
  # buildInputs. TVP's own pkg-config is just the program, so the path is named
  # here instead — the hidden work a distribution does becomes explicit the
  # moment you own the tool.
  preConfigure = ''
    export PKG_CONFIG_PATH="${lib.getDev libxml2}/lib/pkgconfig:${lib.getDev openssl}/lib/pkgconfig:${lib.getDev zlib}/lib/pkgconfig:${lib.getDev ncurses}/lib/pkgconfig:${lib.getDev sqlite}/lib/pkgconfig"
  '';

  configureFlags = [
    "--with-openssl"
    "--with-zlib"
    "--with-readline=${lib.getDev readline}"
    # PEAR fetches from the network at install time, which a sandbox forbids
    # and a reproducible build should not want.
    "--without-pear"
  ];

  meta = {
    description = "Widely-used general-purpose scripting language";
    homepage = "https://www.php.net/";
    license = lib.licenses.php301;
    platforms = lib.platforms.unix;
    mainProgram = "php";
  };

  passthru = {
    inherit version;
    tvp.deps = {
      inherit
        openssl
        zlib
        libxml2
        sqlite
        readline
        ;
    };

    tests = mkTests finalAttrs.finalPackage;
  };
})

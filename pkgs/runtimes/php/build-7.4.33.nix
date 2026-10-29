# PHP 7.4 onward discovers OpenSSL, zlib and external SQLite through
# pkg-config. Older releases require explicit configure prefixes.
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
  testAutoconf,

  version,
  sha256,
  parallelBuild ? false,
  testFeatures ? { },

  # Supplied by default.nix. A fork that drops this argument fails to evaluate.
  mkTests,
}:
stdenv.mkDerivation (
  finalAttrs:
  {
    pname = "php";
    inherit version;

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
          ncurses
          ;
      };

      tvp.features = {
        passwordApi = true;
        shortArraySyntax = true;
        sqlite3Api = true;
        functionEntryEnd = true;
        digestApi = true;
        sqlite2Api = false;
      } // testFeatures;
      tvp.testDeps.autoconf = testAutoconf;
      tests = mkTests finalAttrs.finalPackage;
    };
  }
  // lib.optionalAttrs parallelBuild { enableParallelBuilding = true; }
)

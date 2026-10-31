# PHP 7.1 through 7.3 use explicit library prefixes, but no longer need
# an external crypt provider. SQLite must still be selected explicitly.
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
  cStandard ? null,
  iconvFromBase ? false,
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

    # Older releases live under php<major>/ on museum.php.net.
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
      "--with-openssl=${lib.getDev openssl}"
      "--with-libxml-dir=${lib.getDev libxml2}"
      "--with-zlib=${lib.getDev zlib}"
      "--with-sqlite3=${lib.getDev sqlite}"
      "--with-pdo-sqlite=${lib.getDev sqlite}"
      "--with-readline=${lib.getDev readline}"
      # PEAR fetches from the network at install time, which a sandbox forbids
      # and a reproducible build should not want.
      "--without-pear"
    ] ++ lib.optional iconvFromBase "--with-iconv=${lib.getDev stdenv.cc.libc}";

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
  // lib.optionalAttrs (cStandard != null && lib.versionAtLeast stdenv.cc.version "15") {
    env.NIX_CFLAGS_COMPILE = "-std=${cStandard}";
  }
)

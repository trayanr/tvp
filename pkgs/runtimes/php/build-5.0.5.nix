# PHP 5.0 predates PDO and uses bundled SQLite2, so it has no external
# SQLite3 dependency or PDO configure flag. Flex is still required.
{
  lib,
  stdenv,
  fetchurl,

  openssl,
  zlib,
  libxml2,
  readline,
  ncurses,
  libxcrypt,
  pkg-config,
  flex,
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
      url = "https://museum.php.net/php5/php-${version}.tar.gz";
      inherit sha256;
    };

    # The shipped scanners define yytext in two translation units. Match the
    # common-symbol semantics used by contemporary GCC, without editing them.
    NIX_CFLAGS_COMPILE =
      "-fcommon"
      + lib.optionalString (
        cStandard != null && lib.versionAtLeast stdenv.cc.version "15"
      ) " -std=${cStandard}";

    nativeBuildInputs = [
      pkg-config
      flex
    ];

    buildInputs = [
      openssl
      zlib
      libxml2
      readline
      ncurses
      libxcrypt
    ];

    # nixpkgs' pkg-config carries a setup hook that builds PKG_CONFIG_PATH out of
    # buildInputs. TVP's own pkg-config is just the program, so the path is named
    # here instead — the hidden work a distribution does becomes explicit the
    # moment you own the tool.
    preConfigure = ''
      export PKG_CONFIG_PATH="${lib.getDev libxml2}/lib/pkgconfig:${lib.getDev openssl}/lib/pkgconfig:${lib.getDev zlib}/lib/pkgconfig:${lib.getDev ncurses}/lib/pkgconfig"
    '';

    configureFlags = [
      "--with-openssl=${lib.getDev openssl}"
      "--with-libxml-dir=${lib.getDev libxml2}"
      "--with-zlib=${lib.getDev zlib}"
      "--with-readline=${lib.getDev readline}"
      # PEAR fetches from the network at install time, which a sandbox forbids
      # and a reproducible build should not want.
      "--without-pear"
    ];

    # install-programs does not order bindir creation before parallel copies.
    preInstall = ''mkdir -p "$out/bin"'';

    # Upstream installs both SAPIs as bin/php. Preserve both under distinct
    # names after make install, independent of parallel target ordering.
    postInstall = ''
      install -m755 sapi/cli/php "$out/bin/php"
      install -m755 sapi/cgi/php "$out/bin/php-cgi"
      test -x "$out/bin/phpize"
      test -x "$out/bin/php-config"
    '';

    meta = {
      description = "Widely-used general-purpose scripting language";
      homepage = "https://www.php.net/";
      license = {
        shortName = "PHP-3.0";
        fullName = "PHP License v3.0";
        url = "https://www.php.net/license/3_0.txt";
        free = true;
      };
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
          libxcrypt
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
      tvp.buildDeps = {
        inherit flex;
      };
      tvp.testDeps.autoconf = testAutoconf;
      tests = mkTests finalAttrs.finalPackage;
    };
  }
  // lib.optionalAttrs parallelBuild { enableParallelBuilding = true; }
  // lib.optionalAttrs iconvFromBase {
    # Keep libc iconv detection; only its generated absolute header fallback
    # needs the owned store prefix rather than an absent /usr tree.
    postPatch = ''
      substituteInPlace configure --replace-fail \
        'PHP_ICONV_PREFIX="/usr"' \
        'PHP_ICONV_PREFIX="${lib.getDev stdenv.cc.libc}"'
    '';
  }

)

{ pkgs, tvp }:
let
  tvpLib = tvp.lib;

  defs = tvpLib.packages.mkDefs {
    "5.0.5" = {
      builder = ./build-5.0.5.nix;
      base = tvp.bases.default;
      # The old iconv runtime probes include a header below this prefix.
      opts.iconvFromBase = true;
      # This configure generation uses implicit-int compiler probes.
      opts.cStandard = "gnu89";
      deps = {
        openssl = tvp.packages.openssl_0_9_8zh;
        zlib = tvp.packages.zlib_1_3_2;
        libxml2 = tvp.packages.libxml2_2_8_0;
        readline = tvp.packages.readline_8_3;
        ncurses = tvp.packages.ncurses_6_6;
        libxcrypt = tvp.packages.libxcrypt_4_4_36;
        flex = tvp.packages.flex_2_6_4;
        pkg-config = tvp.packages.pkg-config_0_29_2;
        testAutoconf = tvp.packages.autoconf_2_73;
      };
      opts = {
        parallelBuild = true;
        testFeatures.passwordApi = false;
        testFeatures.shortArraySyntax = false;
        testFeatures.sqlite3Api = false;
        testFeatures.functionEntryEnd = false;
        testFeatures.digestApi = false;
        testFeatures.sqlite2Api = true;
      };
    };
    "5.1.6" = {
      builder = ./build-5.1.6.nix;
      base = tvp.bases.default;
      # The old iconv runtime probes include a header below this prefix.
      opts.iconvFromBase = true;
      # This configure generation uses implicit-int compiler probes.
      opts.cStandard = "gnu89";
      deps = {
        openssl = tvp.packages.openssl_0_9_8zh;
        zlib = tvp.packages.zlib_1_3_2;
        libxml2 = tvp.packages.libxml2_2_8_0;
        readline = tvp.packages.readline_8_3;
        ncurses = tvp.packages.ncurses_6_6;
        libxcrypt = tvp.packages.libxcrypt_4_4_36;
        sqlite = tvp.packages.sqlite_3_53_4;
        flex = tvp.packages.flex_2_6_4;
        pkg-config = tvp.packages.pkg-config_0_29_2;
        testAutoconf = tvp.packages.autoconf_2_73;
      };
      opts = {
        parallelBuild = true;
        testFeatures.passwordApi = false;
        testFeatures.shortArraySyntax = false;
        testFeatures.sqlite3Api = false;
        testFeatures.functionEntryEnd = false;
        testFeatures.digestApi = false;
        testFeatures.sqlite2Api = true;
      };
    };
    "5.2.17" = {
      builder = ./build-5.2.17.nix;
      base = tvp.bases.default;
      # The old iconv runtime probes include a header below this prefix.
      opts.iconvFromBase = true;
      # This configure generation uses implicit-int compiler probes.
      opts.cStandard = "gnu89";
      deps = {
        openssl = tvp.packages.openssl_1_0_2u;
        zlib = tvp.packages.zlib_1_3_2;
        libxml2 = tvp.packages.libxml2_2_8_0;
        readline = tvp.packages.readline_8_3;
        ncurses = tvp.packages.ncurses_6_6;
        libxcrypt = tvp.packages.libxcrypt_4_4_36;
        sqlite = tvp.packages.sqlite_3_53_4;
        pkg-config = tvp.packages.pkg-config_0_29_2;
        testAutoconf = tvp.packages.autoconf_2_73;
      };
      opts = {
        parallelBuild = true;
        testFeatures.passwordApi = false;
        testFeatures.shortArraySyntax = false;
        testFeatures.sqlite3Api = false;
        testFeatures.functionEntryEnd = false;
        testFeatures.digestApi = false;
        testFeatures.sqlite2Api = true;
      };
    };
    "5.3.29" = {
      builder = ./build-5.3.29.nix;
      base = tvp.bases.default;
      # The old iconv runtime probes include a header below this prefix.
      opts.iconvFromBase = true;
      # This configure generation uses implicit-int compiler probes.
      opts.cStandard = "gnu89";
      deps = {
        openssl = tvp.packages.openssl_1_0_2u;
        zlib = tvp.packages.zlib_1_3_2;
        libxml2 = tvp.packages.libxml2_2_9_7;
        readline = tvp.packages.readline_8_3;
        ncurses = tvp.packages.ncurses_6_6;
        libxcrypt = tvp.packages.libxcrypt_4_4_36;
        sqlite = tvp.packages.sqlite_3_53_4;
        pkg-config = tvp.packages.pkg-config_0_29_2;
        testAutoconf = tvp.packages.autoconf_2_73;
      };
      opts = {
        parallelBuild = true;
        testFeatures.passwordApi = false;
        testFeatures.shortArraySyntax = false;
        testFeatures.sqlite2Api = true;
      };
    };
    "5.4.45" = {
      builder = ./build-5.3.29.nix;
      base = tvp.bases.default;
      # The old iconv runtime probes include a header below this prefix.
      opts.iconvFromBase = true;
      # scanf’s original conversion callbacks use pre-C23 unspecified arguments.
      opts.cStandard = "gnu17";
      deps = {
        openssl = tvp.packages.openssl_1_0_2u;
        zlib = tvp.packages.zlib_1_3_2;
        libxml2 = tvp.packages.libxml2_2_9_7;
        readline = tvp.packages.readline_8_3;
        ncurses = tvp.packages.ncurses_6_6;
        libxcrypt = tvp.packages.libxcrypt_4_4_36;
        sqlite = tvp.packages.sqlite_3_53_4;
        pkg-config = tvp.packages.pkg-config_0_29_2;
        testAutoconf = tvp.packages.autoconf_2_73;
      };
      # The historical typed zlib globals constructor predates this callback API.
      opts.compileFlags = [ "-Wno-error=incompatible-pointer-types" ];
      opts = {
        parallelBuild = true;
        testFeatures.passwordApi = false;
      };
    };
    "5.5.38" = {
      builder = ./build-5.3.29.nix;
      base = tvp.bases.default;
      # The old iconv runtime probes include a header below this prefix.
      opts.iconvFromBase = true;
      # scanf’s original conversion callbacks use pre-C23 unspecified arguments.
      opts.cStandard = "gnu17";
      deps = {
        openssl = tvp.packages.openssl_1_0_2u;
        zlib = tvp.packages.zlib_1_3_2;
        libxml2 = tvp.packages.libxml2_2_9_7;
        readline = tvp.packages.readline_8_3;
        ncurses = tvp.packages.ncurses_6_6;
        libxcrypt = tvp.packages.libxcrypt_4_4_36;
        sqlite = tvp.packages.sqlite_3_53_4;
        pkg-config = tvp.packages.pkg-config_0_29_2;
        testAutoconf = tvp.packages.autoconf_2_73;
      };
      opts.parallelBuild = true;
      # 7.0 adds an explicit cast for the typed zlib globals constructor.
      opts.compileFlags = [ "-Wno-error=incompatible-pointer-types" ];
    };
    "7.0.33" = {
      builder = ./build-5.3.29.nix;
      base = tvp.bases.default;
      # The old iconv runtime probes include a header below this prefix.
      opts.iconvFromBase = true;
      # scanf’s original conversion callbacks use pre-C23 unspecified arguments.
      opts.cStandard = "gnu17";
      deps = {
        openssl = tvp.packages.openssl_1_1_1w;
        zlib = tvp.packages.zlib_1_3_2;
        libxml2 = tvp.packages.libxml2_2_9_7;
        readline = tvp.packages.readline_8_3;
        ncurses = tvp.packages.ncurses_6_6;
        libxcrypt = tvp.packages.libxcrypt_4_4_36;
        sqlite = tvp.packages.sqlite_3_53_4;
        pkg-config = tvp.packages.pkg-config_0_29_2;
        testAutoconf = tvp.packages.autoconf_2_73;
      };
      opts.parallelBuild = true;
    };
    "7.1.33" = {
      builder = ./build-7.1.33.nix;
      base = tvp.bases.default;
      # The old iconv runtime probes include a header below this prefix.
      opts.iconvFromBase = true;
      # scanf’s original conversion callbacks use pre-C23 unspecified arguments.
      opts.cStandard = "gnu17";
      deps = {
        openssl = tvp.packages.openssl_1_1_1w;
        zlib = tvp.packages.zlib_1_3_2;
        libxml2 = tvp.packages.libxml2_2_11_9;
        readline = tvp.packages.readline_8_3;
        ncurses = tvp.packages.ncurses_6_6;
        sqlite = tvp.packages.sqlite_3_53_4;
        pkg-config = tvp.packages.pkg-config_0_29_2;
        testAutoconf = tvp.packages.autoconf_2_73;
      };
      opts.parallelBuild = true;
    };
    "7.3.33" = {
      builder = ./build-7.1.33.nix;
      base = tvp.bases.default;
      # The old iconv runtime probes include a header below this prefix.
      opts.iconvFromBase = true;
      deps = {
        openssl = tvp.packages.openssl_1_1_1w;
        zlib = tvp.packages.zlib_1_3_2;
        libxml2 = tvp.packages.libxml2_2_11_9;
        readline = tvp.packages.readline_8_3;
        ncurses = tvp.packages.ncurses_6_6;
        sqlite = tvp.packages.sqlite_3_53_4;
        pkg-config = tvp.packages.pkg-config_0_29_2;
        testAutoconf = tvp.packages.autoconf_2_73;
      };
      opts.parallelBuild = true;
      # php_time() has the old unspecified-argument declaration.
      opts.cStandard = "gnu17";
    };
    "7.4.33" = {
      builder = ./build-7.4.33.nix;
      base = tvp.bases.default;
      # The old iconv runtime probes include a header below this prefix.
      opts.iconvFromBase = true;
      # scanf’s original conversion callbacks use pre-C23 unspecified arguments.
      opts.cStandard = "gnu17";
      deps = {
        openssl = tvp.packages.openssl_1_1_1w;
        zlib = tvp.packages.zlib_1_3_2;
        libxml2 = tvp.packages.libxml2_2_11_9;
        readline = tvp.packages.readline_8_3;
        ncurses = tvp.packages.ncurses_6_6;
        sqlite = tvp.packages.sqlite_3_53_4;
        pkg-config = tvp.packages.pkg-config_0_29_2;
        testAutoconf = tvp.packages.autoconf_2_73;
      };
      opts.parallelBuild = true;
    };
    "8.3.10" = {
      builder = ./build-7.4.33.nix;
      base = tvp.bases.default;
      deps = {
        testAutoconf = tvp.packages.autoconf_2_73;
        openssl = tvp.packages.openssl_3_5_7;
        zlib = tvp.packages.zlib_1_3_2;
        libxml2 = tvp.packages.libxml2_2_15_3;
        readline = tvp.packages.readline_8_3;
        ncurses = tvp.packages.ncurses_6_6;
        sqlite = tvp.packages.sqlite_3_53_4;
        pkg-config = tvp.packages."pkg-config_0_29_2";
      };
    };

    "8.1.0" = {
      builder = ./build-7.4.33.nix;
      base = tvp.bases.default;
      deps = {
        testAutoconf = tvp.packages.autoconf_2_73;
        openssl = tvp.packages.openssl_3_5_7;
        zlib = tvp.packages.zlib_1_3_2;
        # Mutable xmlError callbacks require libxml2 before its 2.12 API change.
        libxml2 = tvp.packages.libxml2_2_11_9;
        readline = tvp.packages.readline_8_3;
        ncurses = tvp.packages.ncurses_6_6;
        sqlite = tvp.packages.sqlite_3_53_4;
        pkg-config = tvp.packages."pkg-config_0_29_2";
      };
    };

    "8.1.31" = {
      builder = ./build-7.4.33.nix;
      base = tvp.bases.default;
      deps = {
        testAutoconf = tvp.packages.autoconf_2_73;
        openssl = tvp.packages.openssl_3_5_7;
        zlib = tvp.packages.zlib_1_3_2;
        # Const xmlError callbacks were added at 8.1.31; ATTRIBUTE_UNUSED
        # still requires libxml2 before 2.14.
        libxml2 = tvp.packages.libxml2_2_13_9;
        readline = tvp.packages.readline_8_3;
        ncurses = tvp.packages.ncurses_6_6;
        sqlite = tvp.packages.sqlite_3_53_4;
        pkg-config = tvp.packages."pkg-config_0_29_2";
      };
    };
    "8.2.0" = {
      builder = ./build-7.4.33.nix;
      base = tvp.bases.default;
      # C99 is upstream’s minimum. It selects the existing GNU atomic branch
      # before upstream guarded Clang-only __c11 builtins at 8.2.16/8.3.3.
      opts.cStandard = "gnu99";
      # Installed atomic headers need the same supported dialect in extensions.
      opts.testFeatures.consumerCStandard = "gnu99";
      deps = {
        testAutoconf = tvp.packages.autoconf_2_73;
        openssl = tvp.packages.openssl_3_5_7;
        zlib = tvp.packages.zlib_1_3_2;
        # Mutable xmlError callbacks require libxml2 before its 2.12 API change.
        libxml2 = tvp.packages.libxml2_2_11_9;
        readline = tvp.packages.readline_8_3;
        ncurses = tvp.packages.ncurses_6_6;
        sqlite = tvp.packages.sqlite_3_53_4;
        pkg-config = tvp.packages."pkg-config_0_29_2";
      };
    };
    "8.2.14" = {
      builder = ./build-7.4.33.nix;
      base = tvp.bases.default;
      # C99 is upstream’s minimum. It selects the existing GNU atomic branch
      # before upstream guarded Clang-only __c11 builtins at 8.2.16/8.3.3.
      opts.cStandard = "gnu99";
      # Installed atomic headers need the same supported dialect in extensions.
      opts.testFeatures.consumerCStandard = "gnu99";
      deps = {
        testAutoconf = tvp.packages.autoconf_2_73;
        openssl = tvp.packages.openssl_3_5_7;
        zlib = tvp.packages.zlib_1_3_2;
        # Const callbacks were added at 8.2.14/8.3.1; ATTRIBUTE_UNUSED
        # still requires libxml2 before 2.14.
        libxml2 = tvp.packages.libxml2_2_13_9;
        readline = tvp.packages.readline_8_3;
        ncurses = tvp.packages.ncurses_6_6;
        sqlite = tvp.packages.sqlite_3_53_4;
        pkg-config = tvp.packages."pkg-config_0_29_2";
      };
    };
    "8.2.16" = {
      builder = ./build-7.4.33.nix;
      base = tvp.bases.default;
      deps = {
        testAutoconf = tvp.packages.autoconf_2_73;
        openssl = tvp.packages.openssl_3_5_7;
        zlib = tvp.packages.zlib_1_3_2;
        # Const callbacks were added at 8.2.14/8.3.1; ATTRIBUTE_UNUSED
        # still requires libxml2 before 2.14.
        libxml2 = tvp.packages.libxml2_2_13_9;
        readline = tvp.packages.readline_8_3;
        ncurses = tvp.packages.ncurses_6_6;
        sqlite = tvp.packages.sqlite_3_53_4;
        pkg-config = tvp.packages."pkg-config_0_29_2";
      };
    };
    "8.0.0" = {
      builder = ./build-7.4.33.nix;
      base = tvp.bases.default;
      # scanf’s original conversion callbacks use pre-C23 unspecified arguments.
      opts.cStandard = "gnu17";
      deps = {
        testAutoconf = tvp.packages.autoconf_2_73;
        # 8.0 predates PHP's OpenSSL 3 support: ext/openssl uses
        # RSA_SSLV23_PADDING, which 3.0.0 removed.
        openssl = tvp.packages.openssl_1_1_1w;
        zlib = tvp.packages.zlib_1_3_2;
        libxml2 = tvp.packages.libxml2_2_11_9;
        readline = tvp.packages.readline_8_3;
        ncurses = tvp.packages.ncurses_6_6;
        sqlite = tvp.packages.sqlite_3_53_4;
        pkg-config = tvp.packages."pkg-config_0_29_2";
      };
    };
  };

  versionTable = tvpLib.packages.mkTable (
    (import ./5.nix { inherit defs; })
    ++ (import ./7.nix { inherit defs; })
    ++ (import ./8.nix { inherit defs; })
  );

  pname = "php";

  canonical = tvpLib.packages.mkVersions {
    infra = {
      inherit (pkgs) lib fetchurl;
    };
    inherit pname;
    inherit versionTable;

    extraArgs = {
      mkTests = pkgs.lib.makeOverridable (
        { pkgs }:
        php:
        import ./tests {
          inherit tvpLib php;
          pkgs =
            (tvpLib.tests.withBase {
              inherit pkgs;
              base.stdenv = php.stdenv;
            })
            // {
              autoconf = php.tvp.testDeps.autoconf;
              automake = tvp.packages.automake_1_19;
              libtool = tvp.packages.libtool_2_6_2;
              gnumake = tvp.packages.gnumake_4_4_1;
            };
        }
      ) { inherit pkgs; };
    };

    packageMeta = {
      upstream = {
        type = "git-tags";
        url = "https://github.com/php/php-src";

        normalise =
          tag:
          if pkgs.lib.hasPrefix "php-" tag then
            pkgs.lib.removeSuffix "REL" (pkgs.lib.removePrefix "php-" tag)
          else
            null;

        # Upstream tags pre-releases in a dozen spellings — RC1, rc1, beta1, b1,
        # dev, pre1 — so a release is recognised by its shape instead: three
        # numbers, plus the patch-level suffix PHP 4 used.
        include = version: builtins.match "[0-9]+\\.[0-9]+\\.[0-9]+(pl[0-9]+)?" version != null;
      };
    };
  };

in
{
  inherit canonical;
  aliases = tvpLib.packages.mkAliases {
    inherit
      pname
      versionTable
      canonical
      ;
  };
}

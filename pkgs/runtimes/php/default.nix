{ pkgs, tvp }:
let
  tvpLib = tvp.lib;

  defs = tvpLib.packages.mkDefs {
    "5.0.5" = {
      builder = ./build-5.0.5.nix;
      base = tvp.bases.default;
      # The old iconv runtime probes include a header below this prefix.
      opts.iconvFromBase = true;
      # Original iconv returns partial output while reporting illegal input.
      opts.testFeatures.iconvPartialOutputOnError = true;
      # This configure generation uses implicit-int compiler probes.
      opts.cStandard = "gnu89";
      deps = {
        openssl = (
          tvp.lib.packages.withConstraint {
            reason = "ext/openssl uses the LHASH type removed in OpenSSL 1.0; native PHP 5.0.5 fails compilation with 1.0.2u. The moving 0.9.8 letter line preserves that public API.";
          } tvp.packages.openssl_0_9_8
        );
        zlib = tvp.packages.zlib_1;
        libxml2 = (
          tvp.lib.packages.withConstraint {
            reason = "DOM documenttype reads xmlOutputBuffer.buffer->content/use directly; libxml2 2.9 changes buffer to opaque xmlBuf. Native PHP 5.0.5/5.1.6/5.2.17 fail against 2.9.7; the 2.8 line retains the public buffer layout.";
          } tvp.packages.libxml2_2_8
        );
        readline = tvp.packages.readline_8;
        ncurses = tvp.packages.ncurses_6;
        libxcrypt = tvp.packages.libxcrypt_4;
        flex = tvp.packages.flex;
        pkg-config = tvp.packages.pkg-config;
        testAutoconf = tvp.packages.autoconf_2;
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
      # Original iconv returns partial output while reporting illegal input.
      opts.testFeatures.iconvPartialOutputOnError = true;
      # This configure generation uses implicit-int compiler probes.
      opts.cStandard = "gnu89";
      deps = {
        openssl = (
          tvp.lib.packages.withConstraint {
            reason = "ext/openssl uses the LHASH type removed in OpenSSL 1.0; native PHP 5.0.5 fails compilation with 1.0.2u. The moving 0.9.8 letter line preserves that public API.";
          } tvp.packages.openssl_0_9_8
        );
        zlib = tvp.packages.zlib_1;
        libxml2 = (
          tvp.lib.packages.withConstraint {
            reason = "DOM documenttype reads xmlOutputBuffer.buffer->content/use directly; libxml2 2.9 changes buffer to opaque xmlBuf. Native PHP 5.0.5/5.1.6/5.2.17 fail against 2.9.7; the 2.8 line retains the public buffer layout.";
          } tvp.packages.libxml2_2_8
        );
        readline = tvp.packages.readline_8;
        ncurses = tvp.packages.ncurses_6;
        libxcrypt = tvp.packages.libxcrypt_4;
        sqlite = tvp.packages.sqlite_3;
        flex = tvp.packages.flex;
        pkg-config = tvp.packages.pkg-config;
        testAutoconf = tvp.packages.autoconf_2;
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
      # Original iconv returns partial output while reporting illegal input.
      opts.testFeatures.iconvPartialOutputOnError = true;
      # This configure generation uses implicit-int compiler probes.
      opts.cStandard = "gnu89";
      deps = {
        openssl = (
          tvp.lib.packages.withConstraint {
            reason = "Consumer reaches OpenSSL structures made opaque in 1.1; use the 1.0 API line.";
          } tvp.packages.openssl_1_0
        );
        zlib = tvp.packages.zlib_1;
        libxml2 = (
          tvp.lib.packages.withConstraint {
            reason = "DOM documenttype reads xmlOutputBuffer.buffer->content/use directly; libxml2 2.9 changes buffer to opaque xmlBuf. Native PHP 5.0.5/5.1.6/5.2.17 fail against 2.9.7; the 2.8 line retains the public buffer layout.";
          } tvp.packages.libxml2_2_8
        );
        readline = tvp.packages.readline_8;
        ncurses = tvp.packages.ncurses_6;
        libxcrypt = tvp.packages.libxcrypt_4;
        sqlite = tvp.packages.sqlite_3;
        pkg-config = tvp.packages.pkg-config;
        testAutoconf = tvp.packages.autoconf_2;
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
      # Original iconv returns partial output while reporting illegal input.
      opts.testFeatures.iconvPartialOutputOnError = true;
      # This configure generation uses implicit-int compiler probes.
      opts.cStandard = "gnu89";
      deps = {
        openssl = (
          tvp.lib.packages.withConstraint {
            reason = "Consumer reaches OpenSSL structures made opaque in 1.1; use the 1.0 API line.";
          } tvp.packages.openssl_1_0
        );
        zlib = tvp.packages.zlib_1;
        libxml2 = (
          tvp.lib.packages.withConstraint {
            reason = "The existing C dialect/warning policy accepts const callbacks. ext/libxml still uses ATTRIBUTE_UNUSED, removed from public libxml2 headers in 2.14. Complete native suites pass with 2.13.9; 2.15.4 fails compilation.";
          } tvp.packages.libxml2_2_13
        );
        readline = tvp.packages.readline_8;
        ncurses = tvp.packages.ncurses_6;
        libxcrypt = tvp.packages.libxcrypt_4;
        sqlite = tvp.packages.sqlite_3;
        pkg-config = tvp.packages.pkg-config;
        testAutoconf = tvp.packages.autoconf_2;
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
      # Preserve execution of the original POSIX readdir_r runtime probe.
      opts.configureProbeFlags = [
        "-Wno-error=implicit-int"
        "-Wno-error=implicit-function-declaration"
      ];
      deps = {
        openssl = (
          tvp.lib.packages.withConstraint {
            reason = "Consumer reaches OpenSSL structures made opaque in 1.1; use the 1.0 API line.";
          } tvp.packages.openssl_1_0
        );
        zlib = tvp.packages.zlib_1;
        libxml2 = (
          tvp.lib.packages.withConstraint {
            reason = "The existing C dialect/warning policy accepts const callbacks. ext/libxml still uses ATTRIBUTE_UNUSED, removed from public libxml2 headers in 2.14. Complete native suites pass with 2.13.9; 2.15.4 fails compilation.";
          } tvp.packages.libxml2_2_13
        );
        readline = tvp.packages.readline_8;
        ncurses = tvp.packages.ncurses_6;
        libxcrypt = tvp.packages.libxcrypt_4;
        sqlite = tvp.packages.sqlite_3;
        pkg-config = tvp.packages.pkg-config;
        testAutoconf = tvp.packages.autoconf_2;
      };
      # The historical typed zlib globals constructor predates this callback API.
      opts.compileFlags = [ "-Wno-error=incompatible-pointer-types" ];
      opts = {
        parallelBuild = true;
        # install-cli and install-pharcmd race in the shipped mkdir helper.
        # Keep parallel compilation; serialise this release's install targets.
        parallelInstall = false;
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
      # Preserve execution of the original POSIX readdir_r runtime probe.
      opts.configureProbeFlags = [
        "-Wno-error=implicit-int"
        "-Wno-error=implicit-function-declaration"
      ];
      deps = {
        openssl = (
          tvp.lib.packages.withConstraint {
            reason = "Consumer reaches OpenSSL structures made opaque in 1.1; use the 1.0 API line.";
          } tvp.packages.openssl_1_0
        );
        zlib = tvp.packages.zlib_1;
        libxml2 = (
          tvp.lib.packages.withConstraint {
            reason = "The existing C dialect/warning policy accepts const callbacks. ext/libxml still uses ATTRIBUTE_UNUSED, removed from public libxml2 headers in 2.14. Complete native suites pass with 2.13.9; 2.15.4 fails compilation.";
          } tvp.packages.libxml2_2_13
        );
        readline = tvp.packages.readline_8;
        ncurses = tvp.packages.ncurses_6;
        libxcrypt = tvp.packages.libxcrypt_4;
        sqlite = tvp.packages.sqlite_3;
        pkg-config = tvp.packages.pkg-config;
        testAutoconf = tvp.packages.autoconf_2;
      };
      opts.parallelBuild = true;
      # 7.0 adds an explicit cast for the typed zlib globals constructor.
      opts.compileFlags = [ "-Wno-error=incompatible-pointer-types" ];
    };
    "5.6.40" = {
      builder = ./build-5.3.29.nix;
      base = tvp.bases.default;
      # The old iconv runtime probes include a header below this prefix.
      opts.iconvFromBase = true;
      # scanf’s original conversion callbacks use pre-C23 unspecified arguments.
      opts.cStandard = "gnu17";
      # Preserve execution of the original POSIX readdir_r runtime probe.
      opts.configureProbeFlags = [
        "-Wno-error=implicit-int"
        "-Wno-error=implicit-function-declaration"
      ];
      deps = {
        openssl = (
          tvp.lib.packages.withConstraint {
            reason = "Consumer reaches OpenSSL structures made opaque in 1.1; use the 1.0 API line.";
          } tvp.packages.openssl_1_0
        );
        zlib = tvp.packages.zlib_1;
        libxml2 = (
          tvp.lib.packages.withConstraint {
            reason = "The existing C dialect/warning policy accepts const callbacks. ext/libxml still uses ATTRIBUTE_UNUSED, removed from public libxml2 headers in 2.14. Complete native suites pass with 2.13.9; 2.15.4 fails compilation.";
          } tvp.packages.libxml2_2_13
        );
        readline = tvp.packages.readline_8;
        ncurses = tvp.packages.ncurses_6;
        libxcrypt = tvp.packages.libxcrypt_4;
        sqlite = tvp.packages.sqlite_3;
        pkg-config = tvp.packages.pkg-config;
        testAutoconf = tvp.packages.autoconf_2;
      };
      opts.parallelBuild = true;
      # 7.0 adds an explicit cast for the typed zlib globals constructor.
      opts.compileFlags = [
        "-Wno-error=incompatible-pointer-types"
        # libmagic file_replace omits its int return type in this release.
        "-Wno-error=implicit-int"
      ];
    };
    "7.0.33" = {
      builder = ./build-5.3.29.nix;
      base = tvp.bases.default;
      # The old iconv runtime probes include a header below this prefix.
      opts.iconvFromBase = true;
      # scanf’s original conversion callbacks use pre-C23 unspecified arguments.
      opts.cStandard = "gnu17";
      # Preserve execution of the original POSIX readdir_r runtime probe.
      opts.configureProbeFlags = [
        "-Wno-error=implicit-int"
        "-Wno-error=implicit-function-declaration"
      ];
      deps = {
        openssl = (
          tvp.lib.packages.withConstraint {
            reason = "ext/openssl uses RSA_SSLV23_PADDING, removed in OpenSSL 3; retain the pre-3 1.1 API line.";
          } tvp.packages.openssl_1_1
        );
        zlib = tvp.packages.zlib_1;
        libxml2 = (
          tvp.lib.packages.withConstraint {
            reason = "DOM itemHashScanner requires mutable xmlChar callback names; libxml2 2.9.8 makes xmlHashScan names const. 2.9.7 is the newest working control; 2.9.8 fails native compilation.";
          } tvp.canonical.libxml2_2_9_7
        );
        readline = tvp.packages.readline_8;
        ncurses = tvp.packages.ncurses_6;
        libxcrypt = tvp.packages.libxcrypt_4;
        sqlite = tvp.packages.sqlite_3;
        pkg-config = tvp.packages.pkg-config;
        testAutoconf = tvp.packages.autoconf_2;
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
      # Preserve execution of the original POSIX readdir_r runtime probe.
      opts.configureProbeFlags = [
        "-Wno-error=implicit-int"
        "-Wno-error=implicit-function-declaration"
      ];
      deps = {
        openssl = (
          tvp.lib.packages.withConstraint {
            reason = "ext/openssl uses RSA_SSLV23_PADDING, removed in OpenSSL 3; retain the pre-3 1.1 API line.";
          } tvp.packages.openssl_1_1
        );
        zlib = tvp.packages.zlib_1;
        libxml2 = (
          tvp.lib.packages.withConstraint {
            reason = "Mutable structured-error callbacks predate the const callback API introduced in libxml2 2.12.";
          } tvp.packages.libxml2_2_11
        );
        readline = tvp.packages.readline_8;
        ncurses = tvp.packages.ncurses_6;
        sqlite = tvp.packages.sqlite_3;
        pkg-config = tvp.packages.pkg-config;
        testAutoconf = tvp.packages.autoconf_2;
      };
      opts.parallelBuild = true;
    };
    "7.3.33" = {
      builder = ./build-7.1.33.nix;
      base = tvp.bases.default;
      # The old iconv runtime probes include a header below this prefix.
      opts.iconvFromBase = true;
      deps = {
        openssl = (
          tvp.lib.packages.withConstraint {
            reason = "ext/openssl uses RSA_SSLV23_PADDING, removed in OpenSSL 3; retain the pre-3 1.1 API line.";
          } tvp.packages.openssl_1_1
        );
        zlib = tvp.packages.zlib_1;
        libxml2 = (
          tvp.lib.packages.withConstraint {
            reason = "Mutable structured-error callbacks predate the const callback API introduced in libxml2 2.12.";
          } tvp.packages.libxml2_2_11
        );
        readline = tvp.packages.readline_8;
        ncurses = tvp.packages.ncurses_6;
        sqlite = tvp.packages.sqlite_3;
        pkg-config = tvp.packages.pkg-config;
        testAutoconf = tvp.packages.autoconf_2;
      };
      opts.parallelBuild = true;
      # php_time() has the old unspecified-argument declaration.
      opts.cStandard = "gnu17";
      # The runtime probe calls close(DIR*) and ignores that result.
      opts.configureProbeFlags = [ "-Wno-error=int-conversion" ];
    };
    "7.4.33" = {
      builder = ./build-7.4.33.nix;
      base = tvp.bases.default;
      # The old iconv runtime probes include a header below this prefix.
      opts.iconvFromBase = true;
      # scanf’s original conversion callbacks use pre-C23 unspecified arguments.
      opts.cStandard = "gnu17";
      deps = {
        openssl = (
          tvp.lib.packages.withConstraint {
            reason = "ext/openssl uses RSA_SSLV23_PADDING, removed in OpenSSL 3; retain the pre-3 1.1 API line.";
          } tvp.packages.openssl_1_1
        );
        zlib = tvp.packages.zlib_1;
        libxml2 = (
          tvp.lib.packages.withConstraint {
            reason = "Mutable structured-error callbacks predate the const callback API introduced in libxml2 2.12.";
          } tvp.packages.libxml2_2_11
        );
        readline = tvp.packages.readline_8;
        ncurses = tvp.packages.ncurses_6;
        sqlite = tvp.packages.sqlite_3;
        pkg-config = tvp.packages.pkg-config;
        testAutoconf = tvp.packages.autoconf_2;
      };
      opts.parallelBuild = true;
    };
    "8.3.10" = {
      builder = ./build-7.4.33.nix;
      base = tvp.bases.default;
      deps = {
        testAutoconf = tvp.packages.autoconf_2;
        openssl = tvp.packages.openssl_3;
        zlib = tvp.packages.zlib_1;
        libxml2 = tvp.packages.libxml2_2;
        readline = tvp.packages.readline_8;
        ncurses = tvp.packages.ncurses_6;
        sqlite = tvp.packages.sqlite_3;
        pkg-config = tvp.packages.pkg-config;
      };
    };

    "8.1.0" = {
      builder = ./build-7.4.33.nix;
      base = tvp.bases.default;
      deps = {
        testAutoconf = tvp.packages.autoconf_2;
        openssl = tvp.packages.openssl_3;
        zlib = tvp.packages.zlib_1;
        # Mutable xmlError callbacks require libxml2 before its 2.12 API change.
        libxml2 = (
          tvp.lib.packages.withConstraint {
            reason = "Mutable structured-error callbacks predate the const callback API introduced in libxml2 2.12.";
          } tvp.packages.libxml2_2_11
        );
        readline = tvp.packages.readline_8;
        ncurses = tvp.packages.ncurses_6;
        sqlite = tvp.packages.sqlite_3;
        pkg-config = tvp.packages.pkg-config;
      };
    };

    "8.1.31" = {
      builder = ./build-7.4.33.nix;
      base = tvp.bases.default;
      deps = {
        testAutoconf = tvp.packages.autoconf_2;
        openssl = tvp.packages.openssl_3;
        zlib = tvp.packages.zlib_1;
        libxml2 = tvp.packages.libxml2_2;
        readline = tvp.packages.readline_8;
        ncurses = tvp.packages.ncurses_6;
        sqlite = tvp.packages.sqlite_3;
        pkg-config = tvp.packages.pkg-config;
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
        testAutoconf = tvp.packages.autoconf_2;
        openssl = tvp.packages.openssl_3;
        zlib = tvp.packages.zlib_1;
        # Mutable xmlError callbacks require libxml2 before its 2.12 API change.
        libxml2 = (
          tvp.lib.packages.withConstraint {
            reason = "Mutable structured-error callbacks predate the const callback API introduced in libxml2 2.12.";
          } tvp.packages.libxml2_2_11
        );
        readline = tvp.packages.readline_8;
        ncurses = tvp.packages.ncurses_6;
        sqlite = tvp.packages.sqlite_3;
        pkg-config = tvp.packages.pkg-config;
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
        testAutoconf = tvp.packages.autoconf_2;
        openssl = tvp.packages.openssl_3;
        zlib = tvp.packages.zlib_1;
        # Const callbacks were added at 8.2.14/8.3.1; ATTRIBUTE_UNUSED
        # still requires libxml2 before 2.14.
        libxml2 = (
          tvp.lib.packages.withConstraint {
            reason = "Callbacks support const, but this definition still uses ATTRIBUTE_UNUSED, removed in libxml2 2.14.";
          } tvp.packages.libxml2_2_13
        );
        readline = tvp.packages.readline_8;
        ncurses = tvp.packages.ncurses_6;
        sqlite = tvp.packages.sqlite_3;
        pkg-config = tvp.packages.pkg-config;
      };
    };
    "8.2.16" = {
      builder = ./build-7.4.33.nix;
      base = tvp.bases.default;
      deps = {
        testAutoconf = tvp.packages.autoconf_2;
        openssl = tvp.packages.openssl_3;
        zlib = tvp.packages.zlib_1;
        # Const callbacks were added at 8.2.14/8.3.1; ATTRIBUTE_UNUSED
        # still requires libxml2 before 2.14.
        libxml2 = (
          tvp.lib.packages.withConstraint {
            reason = "Callbacks support const, but this definition still uses ATTRIBUTE_UNUSED, removed in libxml2 2.14.";
          } tvp.packages.libxml2_2_13
        );
        readline = tvp.packages.readline_8;
        ncurses = tvp.packages.ncurses_6;
        sqlite = tvp.packages.sqlite_3;
        pkg-config = tvp.packages.pkg-config;
      };
    };
    "8.0.0" = {
      builder = ./build-7.4.33.nix;
      base = tvp.bases.default;
      # scanf’s original conversion callbacks use pre-C23 unspecified arguments.
      opts.cStandard = "gnu17";
      deps = {
        testAutoconf = tvp.packages.autoconf_2;
        # 8.0 predates PHP's OpenSSL 3 support: ext/openssl uses
        # RSA_SSLV23_PADDING, which 3.0.0 removed.
        openssl = (
          tvp.lib.packages.withConstraint {
            reason = "ext/openssl uses RSA_SSLV23_PADDING, removed in OpenSSL 3; retain the pre-3 1.1 API line.";
          } tvp.packages.openssl_1_1
        );
        zlib = tvp.packages.zlib_1;
        libxml2 = (
          tvp.lib.packages.withConstraint {
            reason = "Mutable structured-error callbacks predate the const callback API introduced in libxml2 2.12.";
          } tvp.packages.libxml2_2_11
        );
        readline = tvp.packages.readline_8;
        ncurses = tvp.packages.ncurses_6;
        sqlite = tvp.packages.sqlite_3;
        pkg-config = tvp.packages.pkg-config;
      };
    };

    # This upstream release switched to OpenSSL 4 ASN.1 accessors.
    "8.2.31" = {
      builder = ./build-7.4.33.nix;
      base = tvp.bases.default;
      deps = {
        testAutoconf = tvp.packages.autoconf_2;
        openssl = tvp.packages.openssl;
        zlib = tvp.packages.zlib_1;
        libxml2 = tvp.packages.libxml2_2;
        readline = tvp.packages.readline_8;
        ncurses = tvp.packages.ncurses_6;
        sqlite = tvp.packages.sqlite_3;
        pkg-config = tvp.packages.pkg-config;
      };
    };

    # This upstream release switched to OpenSSL 4 ASN.1 accessors.
    "8.3.31" = {
      builder = ./build-7.4.33.nix;
      base = tvp.bases.default;
      deps = {
        testAutoconf = tvp.packages.autoconf_2;
        openssl = tvp.packages.openssl;
        zlib = tvp.packages.zlib_1;
        libxml2 = tvp.packages.libxml2_2;
        readline = tvp.packages.readline_8;
        ncurses = tvp.packages.ncurses_6;
        sqlite = tvp.packages.sqlite_3;
        pkg-config = tvp.packages.pkg-config;
      };
    };

    # This upstream release switched to OpenSSL 4 ASN.1 accessors.
    "8.4.22" = {
      builder = ./build-7.4.33.nix;
      base = tvp.bases.default;
      deps = {
        testAutoconf = tvp.packages.autoconf_2;
        openssl = tvp.packages.openssl;
        zlib = tvp.packages.zlib_1;
        libxml2 = tvp.packages.libxml2_2;
        readline = tvp.packages.readline_8;
        ncurses = tvp.packages.ncurses_6;
        sqlite = tvp.packages.sqlite_3;
        pkg-config = tvp.packages.pkg-config;
      };
    };

    # This upstream release switched to OpenSSL 4 ASN.1 accessors.
    "8.5.7" = {
      builder = ./build-7.4.33.nix;
      base = tvp.bases.default;
      deps = {
        testAutoconf = tvp.packages.autoconf_2;
        openssl = tvp.packages.openssl;
        zlib = tvp.packages.zlib_1;
        libxml2 = tvp.packages.libxml2_2;
        readline = tvp.packages.readline_8;
        ncurses = tvp.packages.ncurses_6;
        sqlite = tvp.packages.sqlite_3;
        pkg-config = tvp.packages.pkg-config;
      };
    };

    # Upstream replaced libxml2 ATTRIBUTE_UNUSED with its own attribute at 8.2.22.
    "8.2.22" = {
      builder = ./build-7.4.33.nix;
      base = tvp.bases.default;
      deps = {
        testAutoconf = tvp.packages.autoconf_2;
        openssl = tvp.packages.openssl_3;
        zlib = tvp.packages.zlib_1;
        libxml2 = tvp.packages.libxml2_2;
        readline = tvp.packages.readline_8;
        ncurses = tvp.packages.ncurses_6;
        sqlite = tvp.packages.sqlite_3;
        pkg-config = tvp.packages.pkg-config;
      };
    };

  };

  versionTable = tvpLib.packages.mkTable (
    (import ./5.nix { inherit defs; })
    ++ (import ./7.nix { inherit defs; })
    ++ (import ./8.nix { inherit defs; })
  );

  pname = "php";

  testDeps = {
    automake = tvp.packages.automake_1;
    libtool = tvp.packages.libtool_2;
    gnumake = tvp.packages.gnumake;
  };
  canonical = tvpLib.packages.mkVersions {
    inherit testDeps;
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
              automake = php.tvp.declaredTestDependencies.automake;
              libtool = php.tvp.declaredTestDependencies.libtool;
              gnumake = php.tvp.declaredTestDependencies.gnumake;
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

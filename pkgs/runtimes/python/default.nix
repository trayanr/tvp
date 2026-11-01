{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  defs = tvpLib.packages.mkDefs {
    "3.5.10" = {
      builder = ./build-3.5.10.nix;
      base = tvp.bases.default;
      opts.linkUnwinder = true;
      deps = rec {
        bash = tvp.packages.bash_5;
        openssl = (
          tvp.lib.packages.withConstraint {
            reason = "The legacy ssl module and upstream TLS tests predate OpenSSL 3 behavior: the 3.7 native upstream control has 14 SSL errors and two failures with 3.6.3; the 1.1 line passes.";
          } tvp.packages.openssl_1_1
        );
        zlib = tvp.packages.zlib_1;
        bzip2 = tvp.packages.bzip2_1;
        xz = tvp.packages.xz_5;
        libffi = tvp.packages.libffi_3;
        sqlite = tvp.packages.sqlite_3;
        gdbm = tvp.packages.gdbm_1;
        readline = tvpLib.packages.withConstraint {
          reason = "Keep the moving Readline 8 line linked to the same Ncurses 6.4 instance required by Python 3.5's public WINDOW field access.";
          parameters.ncurses = ncurses.__tvpSelection;
        } (tvp.packages.readline_8.override { inherit ncurses; });
        ncurses = tvpLib.packages.withConstraint {
          reason = "Modules/_cursesmodule.c reads WINDOW._flags directly. Native 6.4 header control passes; 6.5/6.6 make WINDOW opaque and reject that expression. The full 6.6 consumer silently drops _curses, caught by stdlib and linkage checks.";
        } tvp.packages.ncurses_6_4;
        libxcrypt = tvp.packages.libxcrypt_4;
        pkg-config = tvp.packages.pkg-config;
      };
      patches = [
        {
          file = ./patches/setup-module-selection.patch;
          reason = "Store-layout adaptation: configure the upstream module exclusion list explicitly before Setup.local supported disabled modules, preventing host probes from changing the profile.";
        }
        {
          file = ./patches/subprocess-legacy-shell.patch;
          reason = "Store-layout adaptation: use the declared Bash instead of /bin/sh, which is absent in Nix build sandboxes.";
        }
      ];
      opts.finalizeEx = false;
      opts.textSubprocess = false;
      opts.opensslPrefix = false;
      opts.embedFlag = false;
      opts.systemFfi = true;
      opts.opensslRpath = false;
      opts.platlibdir = false;
      opts.upstreamModules = [
        "test_ssl"
        "test_hashlib"
        "test_ctypes"
        "test_sqlite"
        "test_dbm_gnu"
        "test_dbm_ndbm"
        "test_bz2"
        "test_lzma"
        "test_zlib"
        "test_readline"
      ];
      opts.disabledModules = [
        "_tkinter"
        "_uuid"
        "nis"
      ];
    };
    "3.6.15" = {
      builder = ./build-3.5.10.nix;
      base = tvp.bases.default;
      opts.linkUnwinder = true;
      deps = {
        bash = tvp.packages.bash_5;
        openssl = (
          tvp.lib.packages.withConstraint {
            reason = "The legacy ssl module and upstream TLS tests predate OpenSSL 3 behavior: the 3.7 native upstream control has 14 SSL errors and two failures with 3.6.3; the 1.1 line passes.";
          } tvp.packages.openssl_1_1
        );
        zlib = tvp.packages.zlib_1;
        bzip2 = tvp.packages.bzip2_1;
        xz = tvp.packages.xz_5;
        libffi = tvp.packages.libffi_3;
        sqlite = tvp.packages.sqlite_3;
        gdbm = tvp.packages.gdbm_1;
        readline = tvp.packages.readline_8;
        ncurses = tvp.packages.ncurses_6;
        libxcrypt = tvp.packages.libxcrypt_4;
        pkg-config = tvp.packages.pkg-config;
      };
      patches = [
        {
          file = ./patches/setup-module-selection.patch;
          reason = "Store-layout adaptation: configure the upstream module exclusion list explicitly before Setup.local supported disabled modules, preventing host probes from changing the profile.";
        }
        {
          file = ./patches/subprocess-legacy-shell.patch;
          reason = "Store-layout adaptation: use the declared Bash instead of /bin/sh, which is absent in Nix build sandboxes.";
        }
      ];
      opts.textSubprocess = false;
      opts.opensslPrefix = false;
      opts.embedFlag = false;
      opts.systemFfi = true;
      opts.opensslRpath = false;
      opts.platlibdir = false;
      opts.upstreamModules = [
        "test_ssl"
        "test_hashlib"
        "test_ctypes"
        "test_sqlite"
        "test_dbm_gnu"
        "test_dbm_ndbm"
        "test_bz2"
        "test_lzma"
        "test_zlib"
        "test_readline"
      ];
      opts.disabledModules = [
        "_tkinter"
        "_uuid"
        "nis"
      ];
    };
    "3.7.17" = {
      builder = ./build-3.7.17.nix;
      base = tvp.bases.default;
      opts.linkUnwinder = true;
      deps = {
        bash = tvp.packages.bash_5;
        openssl = (
          tvp.lib.packages.withConstraint {
            reason = "The legacy ssl module and upstream TLS tests predate OpenSSL 3 behavior: the 3.7 native upstream control has 14 SSL errors and two failures with 3.6.3; the 1.1 line passes.";
          } tvp.packages.openssl_1_1
        );
        zlib = tvp.packages.zlib_1;
        bzip2 = tvp.packages.bzip2_1;
        xz = tvp.packages.xz_5;
        libffi = tvp.packages.libffi_3;
        sqlite = tvp.packages.sqlite_3;
        gdbm = tvp.packages.gdbm_1;
        readline = tvp.packages.readline_8;
        ncurses = tvp.packages.ncurses_6;
        libxcrypt = tvp.packages.libxcrypt_4;
        pkg-config = tvp.packages.pkg-config;
      };
      patches = [
        {
          file = ./patches/subprocess-shell.patch;
          reason = "Store-layout adaptation: use the declared Bash instead of /bin/sh, which is absent in Nix build sandboxes.";
        }
      ];
      opts.embedFlag = false;
      opts.systemFfi = true;
      opts.opensslRpath = false;
      opts.platlibdir = false;
      opts.upstreamModules = [
        "test_ssl"
        "test_hashlib"
        "test_ctypes"
        "test_sqlite"
        "test_dbm_gnu"
        "test_dbm_ndbm"
        "test_bz2"
        "test_lzma"
        "test_zlib"
        "test_readline"
      ];
      opts.disabledModules = [
        "_tkinter"
        "_uuid"
        "nis"
      ];
    };
    "3.8.20" = {
      builder = ./build-3.7.17.nix;
      base = tvp.bases.default;
      deps = {
        bash = tvp.packages.bash_5;
        openssl = tvpLib.packages.withConstraint {
          reason = "_ssl.c treats ASN1_R_HEADER_TOO_LONG as normal DER certificate EOF; OpenSSL 3.4 changes it to ASN1_R_NOT_ENOUGH_DATA. Native 3.8/3.9 upstream test_ssl fails on 3.6; the same DER CA control passes on 3.3.7 and fails on 3.4.6/3.5.7/3.6.3. Keep the moving 3.3 line.";
        } tvp.packages.openssl_3_3;
        zlib = tvp.packages.zlib_1;
        bzip2 = tvp.packages.bzip2_1;
        xz = tvp.packages.xz_5;
        libffi = tvp.packages.libffi_3;
        sqlite = tvp.packages.sqlite_3;
        gdbm = tvp.packages.gdbm_1;
        readline = tvp.packages.readline_8;
        ncurses = tvp.packages.ncurses_6;
        libxcrypt = tvp.packages.libxcrypt_4;
        pkg-config = tvp.packages.pkg-config;
      };
      patches = [
        {
          file = ./patches/subprocess-shell.patch;
          reason = "Store-layout adaptation: use the declared Bash instead of /bin/sh, which is absent in Nix build sandboxes.";
        }
      ];
      opts.linkUnwinder = true;
      opts.opensslRpath = false;
      opts.platlibdir = false;
      opts.upstreamModules = [
        "test_ssl"
        "test_hashlib"
        "test_ctypes"
        "test_sqlite"
        "test_dbm_gnu"
        "test_dbm_ndbm"
        "test_bz2"
        "test_lzma"
        "test_zlib"
        "test_readline"
      ];
      opts.disabledModules = [
        "_tkinter"
        "_uuid"
        "nis"
      ];
    };
    "3.9.25" = {
      builder = ./build-3.7.17.nix;
      base = tvp.bases.default;
      opts.linkUnwinder = true;
      deps = {
        bash = tvp.packages.bash_5;
        openssl = tvpLib.packages.withConstraint {
          reason = "_ssl.c treats ASN1_R_HEADER_TOO_LONG as normal DER certificate EOF; OpenSSL 3.4 changes it to ASN1_R_NOT_ENOUGH_DATA. Native 3.8/3.9 upstream test_ssl fails on 3.6; the same DER CA control passes on 3.3.7 and fails on 3.4.6/3.5.7/3.6.3. Keep the moving 3.3 line.";
        } tvp.packages.openssl_3_3;
        zlib = tvp.packages.zlib_1;
        bzip2 = tvp.packages.bzip2_1;
        xz = tvp.packages.xz_5;
        libffi = tvp.packages.libffi_3;
        sqlite = tvp.packages.sqlite_3;
        gdbm = tvp.packages.gdbm_1;
        readline = tvp.packages.readline_8;
        ncurses = tvp.packages.ncurses_6;
        libxcrypt = tvp.packages.libxcrypt_4;
        pkg-config = tvp.packages.pkg-config;
      };
      patches = [
        {
          file = ./patches/subprocess-shell.patch;
          reason = "Store-layout adaptation: use the declared Bash instead of /bin/sh, which is absent in Nix build sandboxes.";
        }
      ];
      opts.opensslRpath = false;
      opts.upstreamModules = [
        "test_ssl"
        "test_hashlib"
        "test_ctypes"
        "test_sqlite"
        "test_dbm_gnu"
        "test_dbm_ndbm"
        "test_bz2"
        "test_lzma"
        "test_zlib"
        "test_readline"
      ];
      opts.disabledModules = [
        "_tkinter"
        "_uuid"
        "nis"
      ];
    };
    "3.10.22" = {
      builder = ./build-3.7.17.nix;
      base = tvp.bases.default;
      opts.linkUnwinder = true;
      deps = {
        bash = tvp.packages.bash_5;
        openssl = tvp.packages.openssl_3;
        zlib = tvp.packages.zlib_1;
        bzip2 = tvp.packages.bzip2_1;
        xz = tvp.packages.xz_5;
        libffi = tvp.packages.libffi_3;
        sqlite = tvp.packages.sqlite_3;
        gdbm = tvp.packages.gdbm_1;
        readline = tvp.packages.readline_8;
        ncurses = tvp.packages.ncurses_6;
        libxcrypt = tvp.packages.libxcrypt_4;
        pkg-config = tvp.packages.pkg-config;
      };
      patches = [
        {
          file = ./patches/subprocess-shell.patch;
          reason = "Store-layout adaptation: use the declared Bash instead of /bin/sh, which is absent in Nix build sandboxes.";
        }
      ];
      opts.upstreamModules = [
        "test_ssl"
        "test_hashlib"
        "test_ctypes"
        "test_sqlite"
        "test_dbm_gnu"
        "test_dbm_ndbm"
        "test_bz2"
        "test_lzma"
        "test_zlib"
        "test_readline"
      ];
      opts.disabledModules = [
        "_tkinter"
        "_uuid"
        "nis"
      ];
    };
    "3.11.18" = {
      builder = ./build-3.7.17.nix;
      base = tvp.bases.default;
      opts.linkUnwinder = true;
      deps = {
        bash = tvp.packages.bash_5;
        openssl = tvp.packages.openssl_3;
        zlib = tvp.packages.zlib_1;
        bzip2 = tvp.packages.bzip2_1;
        xz = tvp.packages.xz_5;
        libffi = tvp.packages.libffi_3;
        sqlite = tvp.packages.sqlite_3;
        gdbm = tvp.packages.gdbm_1;
        readline = tvp.packages.readline_8;
        ncurses = tvp.packages.ncurses_6;
        libxcrypt = tvp.packages.libxcrypt_4;
        pkg-config = tvp.packages.pkg-config;
      };
      patches = [
        {
          file = ./patches/subprocess-shell.patch;
          reason = "Store-layout adaptation: use the declared Bash instead of /bin/sh, which is absent in Nix build sandboxes.";
        }
      ];
      opts.pkgConfigRequired = true;
      opts.disabledModules = [
        "_tkinter"
        "_uuid"
        "nis"
      ];
    };
    "3.12.16" = {
      builder = ./build-3.12.16.nix;
      base = tvp.bases.default;
      opts.linkUnwinder = true;
      deps = {
        bash = tvp.packages.bash_5;
        openssl = tvp.packages.openssl_3;
        zlib = tvp.packages.zlib_1;
        bzip2 = tvp.packages.bzip2_1;
        xz = tvp.packages.xz_5;
        libffi = tvp.packages.libffi_3;
        sqlite = tvp.packages.sqlite_3;
        gdbm = tvp.packages.gdbm_1;
        readline = tvp.packages.readline_8;
        ncurses = tvp.packages.ncurses_6;
        libxcrypt = tvp.packages.libxcrypt_4;
        pkg-config = tvp.packages.pkg-config;
      };
      patches = [
        {
          file = ./patches/subprocess-shell.patch;
          reason = "Store-layout adaptation: use the declared Bash instead of /bin/sh, which is absent in Nix build sandboxes.";
        }
      ];
      opts.disabledModules = [
        "_tkinter"
        "_uuid"
        "nis"
      ];
    };
    "3.13.18" = {
      builder = ./build-3.13.18.nix;
      base = tvp.bases.default;
      opts.linkUnwinder = true;
      deps = {
        bash = tvp.packages.bash_5;
        openssl = tvp.packages.openssl_3;
        zlib = tvp.packages.zlib_1;
        bzip2 = tvp.packages.bzip2_1;
        xz = tvp.packages.xz_5;
        libffi = tvp.packages.libffi_3;
        sqlite = tvp.packages.sqlite_3;
        gdbm = tvp.packages.gdbm_1;
        readline = tvp.packages.readline_8;
        ncurses = tvp.packages.ncurses_6;
        pkg-config = tvp.packages.pkg-config;
      };
      patches = [
        {
          file = ./patches/subprocess-shell.patch;
          reason = "Store-layout adaptation: use the declared Bash instead of /bin/sh, which is absent in Nix build sandboxes.";
        }
      ];
      opts.disabledModules = [
        "_tkinter"
        "_uuid"
      ];
    };
    "3.14.10" = {
      builder = ./build-3.14.10.nix;
      base = tvp.bases.default;
      opts.linkUnwinder = true;
      deps = {
        bash = tvp.packages.bash_5;
        openssl = tvp.packages.openssl_3;
        zlib = tvp.packages.zlib_1;
        bzip2 = tvp.packages.bzip2_1;
        zstd = tvp.packages.zstd_1;
        xz = tvp.packages.xz_5;
        libffi = tvp.packages.libffi_3;
        sqlite = tvp.packages.sqlite_3;
        gdbm = tvp.packages.gdbm_1;
        readline = tvp.packages.readline_8;
        ncurses = tvp.packages.ncurses_6;
        pkg-config = tvp.packages.pkg-config;
      };
      patches = [
        {
          file = ./patches/subprocess-shell.patch;
          reason = "Store-layout adaptation: use the declared Bash instead of /bin/sh, which is absent in Nix build sandboxes.";
        }
      ];
      opts.disabledModules = [
        "_tkinter"
        "_uuid"
      ];
    };
    "3.15.2" = {
      builder = ./build-3.15.2.nix;
      base = tvp.bases.default;
      opts.linkUnwinder = true;
      deps = {
        bash = tvp.packages.bash_5;
        openssl = tvp.packages.openssl;
        zlib = tvp.packages.zlib_1;
        bzip2 = tvp.packages.bzip2_1;
        mpdecimal = tvp.packages.mpdecimal_4;
        zstd = tvp.packages.zstd_1;
        xz = tvp.packages.xz_5;
        libffi = tvp.packages.libffi_3;
        sqlite = tvp.packages.sqlite_3;
        gdbm = tvp.packages.gdbm_1;
        readline = tvp.packages.readline_8;
        ncurses = tvp.packages.ncurses_6;
        pkg-config = tvp.packages.pkg-config;
      };
      patches = [
        {
          file = ./patches/subprocess-shell.patch;
          reason = "Store-layout adaptation: use the declared Bash instead of /bin/sh, which is absent in Nix build sandboxes.";
        }
      ];
      opts.disabledModules = [
        "_tkinter"
        "_uuid"
      ];
    };
  };
  versionTable = tvpLib.packages.mkTable (import ./3.nix { inherit defs; });
  pname = "python";
  canonical = tvpLib.packages.mkVersions {
    infra = {
      inherit (pkgs) lib fetchurl;
    };
    inherit pname versionTable;
    testDeps.patch = tvp.packages.patch;
    packageMeta.upstream = {
      type = "git-tags";
      url = "https://github.com/python/cpython";
      normalise = tag: if pkgs.lib.hasPrefix "v" tag then pkgs.lib.removePrefix "v" tag else null;
      include = version: builtins.match "[0-9]+\\.[0-9]+\\.[0-9]+" version != null;
    };
    extraArgs.mkTests = pkgs.lib.makeOverridable (
      { pkgs }:
      package:
      import ./tests {
        inherit tvpLib package;
        inherit (package.tvp.declaredTestDependencies) patch;

        pkgs = tvpLib.tests.withBase {
          inherit pkgs;
          base.stdenv = package.stdenv;
        };
      }
    ) { inherit pkgs; };

  };
in
{
  inherit canonical;
  aliases = tvpLib.packages.mkAliases { inherit pname versionTable canonical; };
}

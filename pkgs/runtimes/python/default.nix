{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  defs = tvpLib.packages.mkDefs {
    "3.5.10" = {
      builder = ./build-3.5.10.nix;
      base = tvp.bases.gcc9;
      deps = {
        bash = tvp.packages.bash_5_2_37;
        openssl = tvp.packages.openssl_1_1_1w;
        zlib = tvp.packages.zlib_1_3_2;
        bzip2 = tvp.packages.bzip2_1_0_8;
        xz = tvp.packages.xz_5_8_3;
        libffi = tvp.packages.libffi_3_8_0;
        sqlite = tvp.packages.sqlite_3_53_4;
        gdbm = tvp.packages.gdbm_1_26;
        readline = tvp.variants.ncurses64.readline_8_3;
        ncurses = tvp.packages.ncurses_6_4;
        libxcrypt = tvp.packages.libxcrypt_4_4_36;
        pkg-config = tvp.packages.pkg-config_0_29_2;
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
      base = tvp.bases.gcc9;
      deps = {
        bash = tvp.packages.bash_5_2_37;
        openssl = tvp.packages.openssl_1_1_1w;
        zlib = tvp.packages.zlib_1_3_2;
        bzip2 = tvp.packages.bzip2_1_0_8;
        xz = tvp.packages.xz_5_8_3;
        libffi = tvp.packages.libffi_3_8_0;
        sqlite = tvp.packages.sqlite_3_53_4;
        gdbm = tvp.packages.gdbm_1_26;
        readline = tvp.packages.readline_8_3;
        ncurses = tvp.packages.ncurses_6_6;
        libxcrypt = tvp.packages.libxcrypt_4_4_36;
        pkg-config = tvp.packages.pkg-config_0_29_2;
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
        bash = tvp.packages.bash_5_2_37;
        openssl = tvp.packages.openssl_1_1_1w;
        zlib = tvp.packages.zlib_1_3_2;
        bzip2 = tvp.packages.bzip2_1_0_8;
        xz = tvp.packages.xz_5_8_3;
        libffi = tvp.packages.libffi_3_8_0;
        sqlite = tvp.packages.sqlite_3_53_4;
        gdbm = tvp.packages.gdbm_1_26;
        readline = tvp.packages.readline_8_3;
        ncurses = tvp.packages.ncurses_6_6;
        libxcrypt = tvp.packages.libxcrypt_4_4_36;
        pkg-config = tvp.packages.pkg-config_0_29_2;
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
        bash = tvp.packages.bash_5_2_37;
        openssl = tvp.packages.openssl_3_3_7;
        zlib = tvp.packages.zlib_1_3_2;
        bzip2 = tvp.packages.bzip2_1_0_8;
        xz = tvp.packages.xz_5_8_3;
        libffi = tvp.packages.libffi_3_8_0;
        sqlite = tvp.packages.sqlite_3_53_4;
        gdbm = tvp.packages.gdbm_1_26;
        readline = tvp.packages.readline_8_3;
        ncurses = tvp.packages.ncurses_6_6;
        libxcrypt = tvp.packages.libxcrypt_4_4_36;
        pkg-config = tvp.packages.pkg-config_0_29_2;
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
      deps = {
        bash = tvp.packages.bash_5_2_37;
        openssl = tvp.packages.openssl_3_3_7;
        zlib = tvp.packages.zlib_1_3_2;
        bzip2 = tvp.packages.bzip2_1_0_8;
        xz = tvp.packages.xz_5_8_3;
        libffi = tvp.packages.libffi_3_8_0;
        sqlite = tvp.packages.sqlite_3_53_4;
        gdbm = tvp.packages.gdbm_1_26;
        readline = tvp.packages.readline_8_3;
        ncurses = tvp.packages.ncurses_6_6;
        libxcrypt = tvp.packages.libxcrypt_4_4_36;
        pkg-config = tvp.packages.pkg-config_0_29_2;
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
      deps = {
        bash = tvp.packages.bash_5_2_37;
        openssl = tvp.packages.openssl_3_6_3;
        zlib = tvp.packages.zlib_1_3_2;
        bzip2 = tvp.packages.bzip2_1_0_8;
        xz = tvp.packages.xz_5_8_3;
        libffi = tvp.packages.libffi_3_8_0;
        sqlite = tvp.packages.sqlite_3_53_4;
        gdbm = tvp.packages.gdbm_1_26;
        readline = tvp.packages.readline_8_3;
        ncurses = tvp.packages.ncurses_6_6;
        libxcrypt = tvp.packages.libxcrypt_4_4_36;
        pkg-config = tvp.packages.pkg-config_0_29_2;
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
      deps = {
        bash = tvp.packages.bash_5_2_37;
        openssl = tvp.packages.openssl_3_6_3;
        zlib = tvp.packages.zlib_1_3_2;
        bzip2 = tvp.packages.bzip2_1_0_8;
        xz = tvp.packages.xz_5_8_3;
        libffi = tvp.packages.libffi_3_8_0;
        sqlite = tvp.packages.sqlite_3_53_4;
        gdbm = tvp.packages.gdbm_1_26;
        readline = tvp.packages.readline_8_3;
        ncurses = tvp.packages.ncurses_6_6;
        libxcrypt = tvp.packages.libxcrypt_4_4_36;
        pkg-config = tvp.packages.pkg-config_0_29_2;
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
      deps = {
        bash = tvp.packages.bash_5_2_37;
        openssl = tvp.packages.openssl_3_6_3;
        zlib = tvp.packages.zlib_1_3_2;
        bzip2 = tvp.packages.bzip2_1_0_8;
        xz = tvp.packages.xz_5_8_3;
        libffi = tvp.packages.libffi_3_8_0;
        sqlite = tvp.packages.sqlite_3_53_4;
        gdbm = tvp.packages.gdbm_1_26;
        readline = tvp.packages.readline_8_3;
        ncurses = tvp.packages.ncurses_6_6;
        libxcrypt = tvp.packages.libxcrypt_4_4_36;
        pkg-config = tvp.packages.pkg-config_0_29_2;
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
      deps = {
        bash = tvp.packages.bash_5_2_37;
        openssl = tvp.packages.openssl_3_6_3;
        zlib = tvp.packages.zlib_1_3_2;
        bzip2 = tvp.packages.bzip2_1_0_8;
        xz = tvp.packages.xz_5_8_3;
        libffi = tvp.packages.libffi_3_8_0;
        sqlite = tvp.packages.sqlite_3_53_4;
        gdbm = tvp.packages.gdbm_1_26;
        readline = tvp.packages.readline_8_3;
        ncurses = tvp.packages.ncurses_6_6;
        pkg-config = tvp.packages.pkg-config_0_29_2;
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
      deps = {
        bash = tvp.packages.bash_5_2_37;
        openssl = tvp.packages.openssl_3_6_3;
        zlib = tvp.packages.zlib_1_3_2;
        bzip2 = tvp.packages.bzip2_1_0_8;
        zstd = tvp.packages.zstd_1_5_6;
        xz = tvp.packages.xz_5_8_3;
        libffi = tvp.packages.libffi_3_8_0;
        sqlite = tvp.packages.sqlite_3_53_4;
        gdbm = tvp.packages.gdbm_1_26;
        readline = tvp.packages.readline_8_3;
        ncurses = tvp.packages.ncurses_6_6;
        pkg-config = tvp.packages.pkg-config_0_29_2;
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
      deps = {
        bash = tvp.packages.bash_5_2_37;
        openssl = tvp.packages.openssl_3_6_3;
        zlib = tvp.packages.zlib_1_3_2;
        bzip2 = tvp.packages.bzip2_1_0_8;
        mpdecimal = tvp.packages.mpdecimal_4_0_1;
        zstd = tvp.packages.zstd_1_5_6;
        xz = tvp.packages.xz_5_8_3;
        libffi = tvp.packages.libffi_3_8_0;
        sqlite = tvp.packages.sqlite_3_53_4;
        gdbm = tvp.packages.gdbm_1_26;
        readline = tvp.packages.readline_8_3;
        ncurses = tvp.packages.ncurses_6_6;
        pkg-config = tvp.packages.pkg-config_0_29_2;
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

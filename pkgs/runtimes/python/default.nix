{ pkgs, tvp }:
let
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build-3.5.10.nix;
        deps = rec {

          runtimeBash = tvp.packages.bash_5;
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
          readline = tvp.lib.packages.withConstraint {
            reason = "Keep the moving Readline 8 line linked to the same Ncurses 6.4 instance required by Python 3.5's public WINDOW field access.";
            parameters.ncurses = ncurses.__tvpSelection;
          } (tvp.packages.readline_8.override { inherit ncurses; });
          ncurses = tvp.lib.packages.withConstraint {
            reason = "Modules/_cursesmodule.c reads WINDOW._flags directly. Native 6.4 header control passes; 6.5/6.6 make WINDOW opaque and reject that expression. The full 6.6 consumer silently drops _curses, caught by stdlib and linkage checks.";
          } tvp.packages.ncurses_6_4;
          libxcrypt = tvp.packages.libxcrypt_4;
        };
        opts = {
          sourceLayout = {
            opensslRpath = false;
            systemFfi = true;
            opensslPrefix = false;
            platlibdir = false;
          };
          installedInterface = {
            finalizeEx = false;
            embedFlag = false;
            textSubprocess = false;
          };
          upstreamPolicy = {
            modules = [
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
          };
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
      };
      releases."3.5.10" = "sha256-Dw+oaFwdwfHaywtOd3l5a5Cu+Z3B+klnpxudp7V9Sig=";
    }
    {
      def = {
        builder = ./build-3.5.10.nix;
        deps = {

          runtimeBash = tvp.packages.bash_5;
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
        };
        opts = {
          sourceLayout = {
            opensslRpath = false;
            systemFfi = true;
            opensslPrefix = false;
            platlibdir = false;
          };
          installedInterface = {
            embedFlag = false;
            textSubprocess = false;
          };
          upstreamPolicy = {
            modules = [
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
          };
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
      };
      releases."3.6.15" = "sha256-bijXzdbdUT3RkOSbyjly4g/PRVCQzPLvPxoidhQTXZE=";
    }
    {
      def = {
        builder = ./build-3.7.17.nix;
        deps = {

          runtimeBash = tvp.packages.bash_5;
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
        };
        opts = {
          sourceLayout = {
            opensslRpath = false;
            systemFfi = true;
            platlibdir = false;
          };
          installedInterface = {
            embedFlag = false;
          };
          upstreamPolicy = {
            modules = [
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
          };
        };
        patches = [
          {
            file = ./patches/subprocess-shell.patch;
            reason = "Store-layout adaptation: use the declared Bash instead of /bin/sh, which is absent in Nix build sandboxes.";
          }
        ];
      };
      releases."3.7.17" = "sha256-eREFHtBCL9VLj1n/wDD3zyrjDg9hvaGRgAuwQNzk+dI=";
    }
    {
      def = {
        builder = ./build-3.7.17.nix;
        deps = {

          runtimeBash = tvp.packages.bash_5;
          openssl = tvp.lib.packages.withConstraint {
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
        };
        opts = {
          sourceLayout = {
            opensslRpath = false;
            platlibdir = false;
          };
          upstreamPolicy = {
            modules = [
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
          };
        };
        patches = [
          {
            file = ./patches/subprocess-shell.patch;
            reason = "Store-layout adaptation: use the declared Bash instead of /bin/sh, which is absent in Nix build sandboxes.";
          }
          {
            file = ./patches/static-embed-pkgconfig.patch;
            reason = "Export LIBM for installed static embedding consumers.";
          }
        ];
      };
      releases."3.8.20" = "sha256-b7iacSQgHGESXAq0z39olN8zmkDAKDO/0oq012kfr7Q=";
    }
    {
      def = {
        builder = ./build-3.7.17.nix;
        deps = {

          runtimeBash = tvp.packages.bash_5;
          openssl = tvp.lib.packages.withConstraint {
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
        };
        opts = {
          sourceLayout = {
            opensslRpath = false;
          };
          upstreamPolicy = {
            modules = [
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
          };
        };
        patches = [
          {
            file = ./patches/subprocess-shell.patch;
            reason = "Store-layout adaptation: use the declared Bash instead of /bin/sh, which is absent in Nix build sandboxes.";
          }
          {
            file = ./patches/static-embed-pkgconfig.patch;
            reason = "Export LIBM for installed static embedding consumers.";
          }
        ];
      };
      releases."3.9.25" = "sha256-AOB9fA8vDMACQy0e6E0qQNrkBKmTA+P5dwHBCWbJGDQ=";
    }
    {
      def = {
        builder = ./build-3.7.17.nix;
        deps = {

          runtimeBash = tvp.packages.bash_5;
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
        };
        opts = {
          # Distutils emits bare -R with the base's cc driver. The base already
          # supplies the OpenSSL runtime search path through LDFLAGS.
          sourceLayout.opensslRpath = false;
          upstreamPolicy = {
            modules = [
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
          };
        };
        patches = [
          {
            file = ./patches/subprocess-shell.patch;
            reason = "Store-layout adaptation: use the declared Bash instead of /bin/sh, which is absent in Nix build sandboxes.";
          }
          {
            file = ./patches/static-embed-pkgconfig.patch;
            reason = "Export LIBM for installed static embedding consumers.";
          }
        ];
      };
      releases."3.10.22" = "sha256-xh/psaGn7CoLA4jmZBh8N4pTJaieNgbSIKv1vfzLJUM=";
    }
    {
      def = {
        builder = ./build-3.7.17.nix;
        deps = {

          runtimeBash = tvp.packages.bash_5;
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
        };
        opts = {
          sourceLayout = {
            pkgConfigRequired = true;
          };
        };
        patches = [
          {
            file = ./patches/subprocess-shell.patch;
            reason = "Store-layout adaptation: use the declared Bash instead of /bin/sh, which is absent in Nix build sandboxes.";
          }
          {
            file = ./patches/static-embed-pkgconfig.patch;
            reason = "Export LIBM for installed static embedding consumers.";
          }
        ];
      };
      releases."3.11.18" = "sha256-kSDgplOGj242mNNs3ZnlpYkD7JRp5EjyHZj3sW2PopA=";
    }
    {
      def = {
        builder = ./build-3.12.16.nix;
        deps = {

          runtimeBash = tvp.packages.bash_5;
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
        };
        patches = [
          {
            file = ./patches/subprocess-shell.patch;
            reason = "Store-layout adaptation: use the declared Bash instead of /bin/sh, which is absent in Nix build sandboxes.";
          }
          {
            file = ./patches/static-embed-pkgconfig.patch;
            reason = "Export LIBM for installed static embedding consumers.";
          }
        ];
      };
      releases."3.12.16" = "sha256-tXlpFdxF/3Rc+06ZCn58k9b1RjKKECzjFEjWnrw3V1w=";
    }
    {
      def = {
        builder = ./build-3.13.18.nix;
        deps = {

          runtimeBash = tvp.packages.bash_5;
          openssl = tvp.packages.openssl_3;
          zlib = tvp.packages.zlib_1;
          bzip2 = tvp.packages.bzip2_1;
          xz = tvp.packages.xz_5;
          libffi = tvp.packages.libffi_3;
          sqlite = tvp.packages.sqlite_3;
          gdbm = tvp.packages.gdbm_1;
          readline = tvp.packages.readline_8;
          ncurses = tvp.packages.ncurses_6;
        };
        patches = [
          {
            file = ./patches/subprocess-shell.patch;
            reason = "Store-layout adaptation: use the declared Bash instead of /bin/sh, which is absent in Nix build sandboxes.";
          }
          {
            file = ./patches/static-embed-pkgconfig.patch;
            reason = "Export LIBM for installed static embedding consumers.";
          }
        ];
      };
      releases."3.13.18" = "sha256-q7AQLm1K4CdQm8uCMn2d2FUVtEo7qK1TjPxemEcCn2g=";
    }
    {
      def = {
        builder = ./build-3.14.10.nix;
        deps = {

          runtimeBash = tvp.packages.bash_5;
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
        };
        patches = [
          {
            file = ./patches/subprocess-shell.patch;
            reason = "Store-layout adaptation: use the declared Bash instead of /bin/sh, which is absent in Nix build sandboxes.";
          }
          {
            file = ./patches/static-embed-pkgconfig.patch;
            reason = "Export LIBM for installed static embedding consumers.";
          }
        ];
      };
      releases."3.14.10" = "sha256-3kFKVxGavvUnhNiZPjQdU67WNfwrBcJgfZ+YosW3IDI=";
    }
    {
      def = {
        builder = ./build-3.15.2.nix;
        deps = {

          runtimeBash = tvp.packages.bash_5;
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
        };
        patches = [
          {
            file = ./patches/subprocess-shell.patch;
            reason = "Store-layout adaptation: use the declared Bash instead of /bin/sh, which is absent in Nix build sandboxes.";
          }
          {
            file = ./patches/static-embed-pkgconfig.patch;
            reason = "Export LIBM for installed static embedding consumers.";
          }
        ];
      };
      releases."3.15.2" = "sha256-i1U20oAULs9s3+FdEqIbocZeMAu/eyio0M24SVdXl94=";
    }
  ];
  pname = "python";
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable;

    source = tvp.lib.sources.archive {
      url = version: "https://www.python.org/ftp/python/${version}/Python-${version}.tar.xz";
      discovery = {
        type = "git-tags";
        url = "https://github.com/python/cpython";
        normalise = tag: if pkgs.lib.hasPrefix "v" tag then pkgs.lib.removePrefix "v" tag else null;
        include = version: builtins.match "[0-9]+\\.[0-9]+\\.[0-9]+" version != null;
      };
    };
    tests = import ./tests/installed.nix;
    # Suite-only support. Meson/Ninja can depend on this full Python.
    testDeps = {
      patch = tvp.packages.patch;
      cmake = tvp.packages.cmake;
      meson = tvp.packages.meson;
      ninja = tvp.packages.ninja;
    };
  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes.python = family;
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}

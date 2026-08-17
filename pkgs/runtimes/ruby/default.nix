{ pkgs, tvp }:
let
  tvpLib = tvp.lib;

  # Upstream OpenSSL bound (ext/openssl/extconf.rb): >= 1.0.1 for 2.7.0–2.7.4,
  # >= 1.0.1 and < 3.0.0 from 2.7.5. 1.1.1w is the latest satisfying both.
  versionTable = {
    "2.7.0" = {
      builder = ./build-2.7.nix;
      sha256 = "sha256-jJmqk7Xi8byEN9G7vv0nsT52lAJTMfdyRdDAaO8fjL4=";
      deps = {
        openssl = tvp.packages.openssl_1_1_1w;
        readline = pkgs.readline;
        zlib = pkgs.zlib;
        gdbm = pkgs.gdbm;
      };
    };

    "2.7.1" = {
      builder = ./build-2.7.nix;
      sha256 = "sha256-1BhIO90AAFdsE3BXESGm6yRYIRbbC3uyAF6Q4lDq5Bg=";
      deps = {
        openssl = tvp.packages.openssl_1_1_1w;
        readline = pkgs.readline;
        zlib = pkgs.zlib;
        gdbm = pkgs.gdbm;
      };
    };

    "2.7.2" = {
      builder = ./build-2.7.nix;
      sha256 = "sha256-blcG0NTuTh4viD2512hYa00GVn3r6jU8eW7EXoMhw9Q=";
      deps = {
        openssl = tvp.packages.openssl_1_1_1w;
        readline = pkgs.readline;
        zlib = pkgs.zlib;
        gdbm = pkgs.gdbm;
      };
    };

    "2.7.3" = {
      builder = ./build-2.7.nix;
      sha256 = "sha256-iSWpXjHY8sgXSQJaUqVE6h0F2tGHlOaChwkmi5LlUzg=";
      deps = {
        openssl = tvp.packages.openssl_1_1_1w;
        readline = pkgs.readline;
        zlib = pkgs.zlib;
        gdbm = pkgs.gdbm;
      };
    };

    "2.7.4" = {
      builder = ./build-2.7.nix;
      sha256 = "sha256-MEMJkIlgiFn8jM5/n9zKofU6RiRX44OOw7JafWCfvFs=";
      deps = {
        openssl = tvp.packages.openssl_1_1_1w;
        readline = pkgs.readline;
        zlib = pkgs.zlib;
        gdbm = pkgs.gdbm;
      };
    };

    "2.7.5" = {
      builder = ./build-2.7.nix;
      sha256 = "sha256-J1W5AKISNbRDuxba3ZAy94TUqI8UPYUrxdFU8iuHgfE=";
      deps = {
        openssl = tvp.packages.openssl_1_1_1w;
        readline = pkgs.readline;
        zlib = pkgs.zlib;
        gdbm = pkgs.gdbm;
      };
    };

    "2.7.6" = {
      builder = ./build-2.7.nix;
      sha256 = "sha256-5yA7DMCUQu0sCJNtSD+KwUDsHHLje7XEAWRreGbLXRA=";
      deps = {
        openssl = tvp.packages.openssl_1_1_1w;
        readline = pkgs.readline;
        zlib = pkgs.zlib;
        gdbm = pkgs.gdbm;
      };
    };

    "2.7.7" = {
      builder = ./build-2.7.nix;
      sha256 = "sha256-4QEn22kdf/NkAs/oj0GMjQJaPx7qkgRLFi3XLwuMe5A=";
      deps = {
        openssl = tvp.packages.openssl_1_1_1w;
        readline = pkgs.readline;
        zlib = pkgs.zlib;
        gdbm = pkgs.gdbm;
      };
    };

    "2.7.8" = {
      builder = ./build-2.7.nix;
      sha256 = "sha256-wtq2PLyPKgVSYQitQZ76Y6Z+1AdNu8+fwrHKZky0W6A=";
      deps = {
        openssl = tvp.packages.openssl_1_1_1w;
        readline = pkgs.readline;
        zlib = pkgs.zlib;
        gdbm = pkgs.gdbm;
      };
    };
  };

  canonical = tvpLib.packages.mkVersions {
    inherit (pkgs) callPackage;
    pname = "ruby";
    inherit versionTable;

    extraArgs = {
      mkTests =
        ruby:
        import ./tests {
          inherit pkgs tvpLib ruby;
        };
    };
  };

  aliases = {
    ruby_2_7 = canonical.ruby_2_7_8;
    ruby_2 = canonical.ruby_2_7_8;
    ruby = canonical.ruby_2_7_8;
  };
in
canonical // tvpLib.packages.checkAliases { inherit canonical aliases; }

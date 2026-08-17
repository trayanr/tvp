{ pkgs, tvp }:
{
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

}

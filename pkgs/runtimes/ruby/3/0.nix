{ pkgs, tvp }:
{
  "3.0.0" = {
    builder = ../build-2.7.nix;
    sha256 = "sha256-oT7RQaHBjrlnqsHjP01q1fIb4axUPDRODW/u7lSvjig=";
    deps = {
      openssl = tvp.packages.openssl_1_1_1w;
      readline = pkgs.readline;
      zlib = pkgs.zlib;
      gdbm = pkgs.gdbm;
    };
  };

  "3.0.1" = {
    builder = ../build-2.7.nix;
    sha256 = "sha256-Npgl2yGZ9q7vFrQI32oE663bZk+5rw7Ixoawznq3dyc=";
    deps = {
      openssl = tvp.packages.openssl_1_1_1w;
      readline = pkgs.readline;
      zlib = pkgs.zlib;
      gdbm = pkgs.gdbm;
    };
  };

  "3.0.2" = {
    builder = ../build-2.7.nix;
    sha256 = "sha256-UIXe4K2fBplqis7H6+pKhzXm+sIvIuLZjD8rw7735vE=";
    deps = {
      openssl = tvp.packages.openssl_1_1_1w;
      readline = pkgs.readline;
      zlib = pkgs.zlib;
      gdbm = pkgs.gdbm;
    };
  };

  "3.0.3" = {
    builder = ../build-2.7.nix;
    sha256 = "sha256-NYaGHLLfVpcCh/D9g/J0vZIFiHLYMNFVcLNt738akqw=";
    deps = {
      openssl = tvp.packages.openssl_1_1_1w;
      readline = pkgs.readline;
      zlib = pkgs.zlib;
      gdbm = pkgs.gdbm;
    };
  };

  "3.0.4" = {
    builder = ../build-2.7.nix;
    sha256 = "sha256-cLR8IHrwS86azqJiMI+0KJPT4kTzmkq8WGkgoccjcis=";
    deps = {
      openssl = tvp.packages.openssl_1_1_1w;
      readline = pkgs.readline;
      zlib = pkgs.zlib;
      gdbm = pkgs.gdbm;
    };
  };

  "3.0.5" = {
    builder = ../build-2.7.nix;
    sha256 = "sha256-mvxjgKAnpP4a4aPi7MtrSXucWsBjHBLKVvm3vrSEh3Y=";
    deps = {
      openssl = tvp.packages.openssl_1_1_1w;
      readline = pkgs.readline;
      zlib = pkgs.zlib;
      gdbm = pkgs.gdbm;
    };
  };

  "3.0.6" = {
    builder = ../build-2.7.nix;
    sha256 = "sha256-bmy9SQAw15EMD/IO3vq0KU380QRvD49H94tZeYesaD4=";
    deps = {
      openssl = tvp.packages.openssl_1_1_1w;
      readline = pkgs.readline;
      zlib = pkgs.zlib;
      gdbm = pkgs.gdbm;
    };
  };

  "3.0.7" = {
    builder = ../build-2.7.nix;
    sha256 = "sha256-KjQRl38oUEMRNrD6uK1Trwn7dN8u4vT7fxGzeP4DQ4g=";
    deps = {
      openssl = tvp.packages.openssl_1_1_1w;
      readline = pkgs.readline;
      zlib = pkgs.zlib;
      gdbm = pkgs.gdbm;
    };
  };

}

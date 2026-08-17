# 4.0 builds YJIT and ZJIT from one Rust crate that requires edition 2024, so
# rustc >= 1.85; the pinned nixpkgs ships 1.80.1. Both JITs are therefore off
# here, which is NOT upstream's default. Flip them on once TVP owns a Rust
# toolchain new enough.
{ pkgs, tvp }:
{
  "4.0.0" = {
    builder = ./build-4.0.nix;
    sha256 = "sha256-LoOJyMByy2WMk6E3JzLZ6shAgsiLBldQ2x5SpaxjAnE=";
    deps = {
      openssl = tvp.packages.openssl_1_1_1w;
      zlib = pkgs.zlib;
      libyaml = pkgs.libyaml;
      libffi = pkgs.libffi;
      rustc = pkgs.rustc;
      yjit = false;
      zjit = false;
    };
  };

  "4.0.1" = {
    builder = ./build-4.0.nix;
    sha256 = "sha256-OSS+LQXbMPTjX4Wb8Ci+hfS33QFxQUL9gj5K9d4vr50=";
    deps = {
      openssl = tvp.packages.openssl_1_1_1w;
      zlib = pkgs.zlib;
      libyaml = pkgs.libyaml;
      libffi = pkgs.libffi;
      rustc = pkgs.rustc;
      yjit = false;
      zjit = false;
    };
  };

  "4.0.2" = {
    builder = ./build-4.0.nix;
    sha256 = "sha256-UVArJrULaN9JYzNspB42jN6SySj6+RZU3kxMF5H4Kqw=";
    deps = {
      openssl = tvp.packages.openssl_1_1_1w;
      zlib = pkgs.zlib;
      libyaml = pkgs.libyaml;
      libffi = pkgs.libffi;
      rustc = pkgs.rustc;
      yjit = false;
      zjit = false;
    };
  };

  "4.0.3" = {
    builder = ./build-4.0.nix;
    sha256 = "sha256-d5ZKzDcNXIN1uVAuW6bBPAPvkaueufUhyE+0K5yaaw8=";
    deps = {
      openssl = tvp.packages.openssl_1_1_1w;
      zlib = pkgs.zlib;
      libyaml = pkgs.libyaml;
      libffi = pkgs.libffi;
      rustc = pkgs.rustc;
      yjit = false;
      zjit = false;
    };
  };

  "4.0.4" = {
    builder = ./build-4.0.nix;
    sha256 = "sha256-819u36Pauz9yP50M8ZBsZRKud/TkEqseaMxukdIw+oA=";
    deps = {
      openssl = tvp.packages.openssl_1_1_1w;
      zlib = pkgs.zlib;
      libyaml = pkgs.libyaml;
      libffi = pkgs.libffi;
      rustc = pkgs.rustc;
      yjit = false;
      zjit = false;
    };
  };

  "4.0.5" = {
    builder = ./build-4.0.nix;
    sha256 = "sha256-fWFJB5pj+K4dMmyfplxgGbotwxVerns5FZgXkRyIlY4=";
    deps = {
      openssl = tvp.packages.openssl_1_1_1w;
      zlib = pkgs.zlib;
      libyaml = pkgs.libyaml;
      libffi = pkgs.libffi;
      rustc = pkgs.rustc;
      yjit = false;
      zjit = false;
    };
  };

  "4.0.6" = {
    builder = ./build-4.0.nix;
    sha256 = "sha256-g30pno993yvjGiKaen4BnTVJeYJRF5iayzsysam+Jio=";
    deps = {
      openssl = tvp.packages.openssl_1_1_1w;
      zlib = pkgs.zlib;
      libyaml = pkgs.libyaml;
      libffi = pkgs.libffi;
      rustc = pkgs.rustc;
      yjit = false;
      zjit = false;
    };
  };

}

{ pkgs, tvp }:
{
  # Upstream shipped this tarball with RUBY_PATCHLEVEL -1, marking it a
  # development build, so Ruby appends RUBY_ABI_VERSION to its lib directory.
  # 3.4.1 restored patchlevel 0 and the suffix goes away again.
  "3.4.0" = {
    builder = ../build-3.3.nix;
    sha256 = "sha256-BoyFI0QhdL00AOeG9KaVI1LIKxufYhD9F/tIIwhtM3k=";
    deps = {
      libDir = "3.4.0+1";
      openssl = tvp.packages.openssl_3_5_7;
      zlib = pkgs.zlib;
      libyaml = pkgs.libyaml;
      libffi = pkgs.libffi;
      rustc = pkgs.rustc;
    };
  };

  "3.4.1" = {
    builder = ../build-3.3.nix;
    sha256 = "sha256-PTheXSLTaLBkyBehPtjjzD9xp3BdftG654ATwzqnyH8=";
    deps = {
      openssl = tvp.packages.openssl_3_5_7;
      zlib = pkgs.zlib;
      libyaml = pkgs.libyaml;
      libffi = pkgs.libffi;
      rustc = pkgs.rustc;
    };
  };

  "3.4.2" = {
    builder = ../build-3.3.nix;
    sha256 = "sha256-QTKKwh8r/dfeazVl708N11QzVNN+lvFXoVUqa9DrNks=";
    deps = {
      openssl = tvp.packages.openssl_3_5_7;
      zlib = pkgs.zlib;
      libyaml = pkgs.libyaml;
      libffi = pkgs.libffi;
      rustc = pkgs.rustc;
    };
  };

  "3.4.3" = {
    builder = ../build-3.3.nix;
    sha256 = "sha256-VaTNHcvlyifPZeiak1pILCuyKEgyk5JmVRwOxotDf0Y=";
    deps = {
      openssl = tvp.packages.openssl_3_5_7;
      zlib = pkgs.zlib;
      libyaml = pkgs.libyaml;
      libffi = pkgs.libffi;
      rustc = pkgs.rustc;
    };
  };

  "3.4.4" = {
    builder = ../build-3.3.nix;
    sha256 = "sha256-oFl7/fMS4BDv0e/6qNfx14MxRv3BeVDKqBWP+j3L+oU=";
    deps = {
      openssl = tvp.packages.openssl_3_5_7;
      zlib = pkgs.zlib;
      libyaml = pkgs.libyaml;
      libffi = pkgs.libffi;
      rustc = pkgs.rustc;
    };
  };

  "3.4.5" = {
    builder = ../build-3.3.nix;
    sha256 = "sha256-HYjYontEL93kqgbcmehrC78LKIlj2EMxEt1frHmP1e4=";
    deps = {
      openssl = tvp.packages.openssl_3_5_7;
      zlib = pkgs.zlib;
      libyaml = pkgs.libyaml;
      libffi = pkgs.libffi;
      rustc = pkgs.rustc;
    };
  };

  "3.4.6" = {
    builder = ../build-3.3.nix;
    sha256 = "sha256-48Gauej0GzcjEk+8ARTN58v1XmWqnFjBKs2J7JwN0bk=";
    deps = {
      openssl = tvp.packages.openssl_3_5_7;
      zlib = pkgs.zlib;
      libyaml = pkgs.libyaml;
      libffi = pkgs.libffi;
      rustc = pkgs.rustc;
    };
  };

  "3.4.7" = {
    builder = ../build-3.3.nix;
    sha256 = "sha256-I4FabQlWlveRkJD9w+L5RZssg9VyJLLkRs4fX3Mz7zY=";
    deps = {
      openssl = tvp.packages.openssl_3_5_7;
      zlib = pkgs.zlib;
      libyaml = pkgs.libyaml;
      libffi = pkgs.libffi;
      rustc = pkgs.rustc;
    };
  };

  "3.4.8" = {
    builder = ../build-3.3.nix;
    sha256 = "sha256-U8TdrUH7thifH17g21elHVS9H4f4dVs9aGBBVqNbBFs=";
    deps = {
      openssl = tvp.packages.openssl_3_5_7;
      zlib = pkgs.zlib;
      libyaml = pkgs.libyaml;
      libffi = pkgs.libffi;
      rustc = pkgs.rustc;
    };
  };

  "3.4.9" = {
    builder = ../build-3.3.nix;
    sha256 = "sha256-e7TU9egHzCclHRTZ1ghtGCxbJYdRkeRKsVtwnNen3Zw=";
    deps = {
      openssl = tvp.packages.openssl_3_5_7;
      zlib = pkgs.zlib;
      libyaml = pkgs.libyaml;
      libffi = pkgs.libffi;
      rustc = pkgs.rustc;
    };
  };

  "3.4.10" = {
    builder = ../build-3.3.nix;
    sha256 = "sha256-7O4tByoU8tFDR91W39j+XDEwq/URe/qsvaD075zEKew=";
    deps = {
      openssl = tvp.packages.openssl_3_5_7;
      zlib = pkgs.zlib;
      libyaml = pkgs.libyaml;
      libffi = pkgs.libffi;
      rustc = pkgs.rustc;
    };
  };

}

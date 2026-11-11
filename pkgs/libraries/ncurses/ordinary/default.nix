{
  tvp,
  tvpLib,
  candidate,
  constructionTool,
  fetchurl,
}:
tvpLib.packages.mkDefs {
  "6.0" = {
    constructor = tvp.builder;
    builder = ./build-6.0.nix;
    base = candidate.base;
    source =
      { version, sha256 }:
      fetchurl {
        urls = [
          "https://mirrors.kernel.org/gnu/ncurses/ncurses-${version}.tar.gz"
          "https://ftp.gnu.org/gnu/ncurses/ncurses-${version}.tar.gz"
        ];
        inherit sha256;
      };
    testContext =
      package:
      tvpLib.tests.fromPackage {
        builder = tvp.builder;
        inherit package;
      };
    helpers = {
      inherit tvp;
    };
    deps = {
      bash = constructionTool "bash";
      coreutils = constructionTool "coreutils";
      gnumake = constructionTool "make";
      gnutar = constructionTool "tar";
      gzip = constructionTool "gzip";
      python = constructionTool "python";
      perl = constructionTool "perl";
      binutils = constructionTool "binutils";
      patchelf = constructionTool "patchelf";
      sed = constructionTool "sed";
      grep = constructionTool "grep";
      gawk = constructionTool "gawk";
      diffutils = constructionTool "diffutils";
      findutils = constructionTool "findutils";
      pkgConfig = constructionTool "pkgConfig";
    };
  };
  "6.2" = {
    constructor = tvp.builder;
    builder = ./build-6.2.nix;
    base = candidate.base;
    source =
      { version, sha256 }:
      fetchurl {
        urls = [
          "https://mirrors.kernel.org/gnu/ncurses/ncurses-${version}.tar.gz"
          "https://ftp.gnu.org/gnu/ncurses/ncurses-${version}.tar.gz"
        ];
        inherit sha256;
      };
    testContext =
      package:
      tvpLib.tests.fromPackage {
        builder = tvp.builder;
        inherit package;
      };
    helpers = {
      inherit tvp;
    };
    deps = {
      bash = constructionTool "bash";
      coreutils = constructionTool "coreutils";
      gnumake = constructionTool "make";
      gnutar = constructionTool "tar";
      gzip = constructionTool "gzip";
      python = constructionTool "python";
      perl = constructionTool "perl";
      binutils = constructionTool "binutils";
      patchelf = constructionTool "patchelf";
      sed = constructionTool "sed";
      grep = constructionTool "grep";
      gawk = constructionTool "gawk";
      diffutils = constructionTool "diffutils";
      findutils = constructionTool "findutils";
      pkgConfig = constructionTool "pkgConfig";
    };
  };
  "6.4" = {
    constructor = tvp.builder;
    builder = ./build-6.4.nix;
    base = candidate.base;
    source =
      { version, sha256 }:
      fetchurl {
        urls = [
          "https://mirrors.kernel.org/gnu/ncurses/ncurses-${version}.tar.gz"
          "https://ftp.gnu.org/gnu/ncurses/ncurses-${version}.tar.gz"
        ];
        inherit sha256;
      };
    testContext =
      package:
      tvpLib.tests.fromPackage {
        builder = tvp.builder;
        inherit package;
      };
    helpers = {
      inherit tvp;
    };
    deps = {
      bash = constructionTool "bash";
      coreutils = constructionTool "coreutils";
      gnumake = constructionTool "make";
      gnutar = constructionTool "tar";
      gzip = constructionTool "gzip";
      python = constructionTool "python";
      perl = constructionTool "perl";
      binutils = constructionTool "binutils";
      patchelf = constructionTool "patchelf";
      sed = constructionTool "sed";
      grep = constructionTool "grep";
      gawk = constructionTool "gawk";
      diffutils = constructionTool "diffutils";
      findutils = constructionTool "findutils";
      pkgConfig = constructionTool "pkgConfig";
    };
  };
}

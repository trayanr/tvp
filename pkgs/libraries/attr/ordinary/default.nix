{
  tvp,
  tvpLib,
  candidate,
  constructionTool,
}:
tvpLib.packages.mkDefs {
  "2.5.0" = {
    constructor = tvp.builder;
    builder = ./build-2.5.0.nix;
    base = candidate.base;
    source =
      { version, sha256 }:
      import <nix/fetchurl.nix> {
        url = "https://download.savannah.nongnu.org/releases/attr/attr-${version}.tar.gz";
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
    };
    opts.libraryFile = "libattr.so.1.1.250";
  };
  "2.5.1" = {
    constructor = tvp.builder;
    builder = ./build-2.5.0.nix;
    base = candidate.base;
    source =
      { version, sha256 }:
      import <nix/fetchurl.nix> {
        url = "https://download.savannah.nongnu.org/releases/attr/attr-${version}.tar.gz";
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
    };
    opts.libraryFile = "libattr.so.1.1.2501";
  };
  "2.5.2" = {
    constructor = tvp.builder;
    builder = ./build-2.5.0.nix;
    base = candidate.base;
    source =
      { version, sha256 }:
      import <nix/fetchurl.nix> {
        url = "https://download.savannah.nongnu.org/releases/attr/attr-${version}.tar.gz";
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
    };
    opts.libraryFile = "libattr.so.1.1.2502";
  };
}

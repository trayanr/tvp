{
  tvp,
  tvpLib,
  candidate,
  constructionTool,
  fetchurl,
}:
tvpLib.packages.mkDefs {
  "0.0.1" = {
    constructor = tvp.builder;
    builder = ./build-0.0.1.nix;
    base = candidate.base;
    source =
      { version, sha256 }:
      fetchurl {
        url = "https://pyyaml.org/download/libyaml/yaml-${version}.tar.gz";
        inherit sha256;
      };
    helpers = {
      inherit tvp;
    };
    testContext =
      package:
      tvpLib.tests.fromPackage {
        builder = tvp.builder;
        inherit package;
      };
    deps = {
      bash = constructionTool "bash";
      coreutils = constructionTool "coreutils";
      pkgConfig = constructionTool "pkgConfig";
      gnumake = constructionTool "make";
      gnutar = constructionTool "tar";
      gzip = constructionTool "gzip";
      python = constructionTool "python";
      binutils = constructionTool "binutils";
      patchelf = constructionTool "patchelf";
      sed = constructionTool "sed";
      grep = constructionTool "grep";
      gawk = constructionTool "gawk";
      diffutils = constructionTool "diffutils";
      findutils = constructionTool "findutils";
      file = tvp.packages.file;
    };
    opts = {
      preparation = {
        "selections" = [
          "configure"
          "config"
          "tests"
        ];
        "shellFragments" = {
          "config/ltmain.sh" = [ "# ltmain.sh - Provide generalized library-building support services." ];
        };
        "libtoolAnchors" = {
          "config/ltmain.sh" = 1;
        };
      };
    };
  };
  "0.1.1" = {
    constructor = tvp.builder;
    builder = ./build-0.1.1.nix;
    base = candidate.base;
    source =
      { version, sha256 }:
      fetchurl {
        url = "https://pyyaml.org/download/libyaml/yaml-${version}.tar.gz";
        inherit sha256;
      };
    helpers = {
      inherit tvp;
    };
    testContext =
      package:
      tvpLib.tests.fromPackage {
        builder = tvp.builder;
        inherit package;
      };
    deps = {
      bash = constructionTool "bash";
      coreutils = constructionTool "coreutils";
      pkgConfig = constructionTool "pkgConfig";
      gnumake = constructionTool "make";
      gnutar = constructionTool "tar";
      gzip = constructionTool "gzip";
      python = constructionTool "python";
      binutils = constructionTool "binutils";
      patchelf = constructionTool "patchelf";
      sed = constructionTool "sed";
      grep = constructionTool "grep";
      gawk = constructionTool "gawk";
      diffutils = constructionTool "diffutils";
      findutils = constructionTool "findutils";
      file = tvp.packages.file;
    };
    opts = {
      preparation = {
        "selections" = [
          "configure"
          "config"
          "tests"
        ];
        "shellFragments" = {
          "config/ltmain.sh" = [
            "# ltmain.sh - Provide generalized library-building support services."
            "# Generated from ltmain.m4sh."
          ];
        };
        "libtoolAnchors" = {
          "config/ltmain.sh" = 1;
        };
      };
    };
  };
  "0.1.4" = {
    constructor = tvp.builder;
    builder = ./build-0.1.4.nix;
    base = candidate.base;
    source =
      { version, sha256 }:
      fetchurl {
        url = "https://pyyaml.org/download/libyaml/yaml-${version}.tar.gz";
        inherit sha256;
      };
    helpers = {
      inherit tvp;
    };
    testContext =
      package:
      tvpLib.tests.fromPackage {
        builder = tvp.builder;
        inherit package;
      };
    deps = {
      bash = constructionTool "bash";
      coreutils = constructionTool "coreutils";
      pkgConfig = constructionTool "pkgConfig";
      gnumake = constructionTool "make";
      gnutar = constructionTool "tar";
      gzip = constructionTool "gzip";
      python = constructionTool "python";
      binutils = constructionTool "binutils";
      patchelf = constructionTool "patchelf";
      sed = constructionTool "sed";
      grep = constructionTool "grep";
      gawk = constructionTool "gawk";
      diffutils = constructionTool "diffutils";
      findutils = constructionTool "findutils";
      file = tvp.packages.file;
    };
    opts = {
      preparation = {
        "selections" = [
          "configure"
          "config"
          "tests"
        ];
        "shellFragments" = {
          "config/ltmain.sh" = [
            "# Generated from ltmain.m4sh."
            ""
          ];
        };
        "libtoolAnchors" = {
          "config/ltmain.sh" = 1;
        };
      };
    };
  };
}

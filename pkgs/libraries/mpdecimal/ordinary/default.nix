{
  tvp,
  tvpLib,
  candidate,
  constructionTool,
  fetchurl,
}:
tvpLib.packages.mkDefs {
  "4.0.0" = {
    constructor = tvp.builder;
    builder = ./build-4.0.0.nix;
    base = candidate.base;
    source =
      { version, sha256 }:
      fetchurl {
        url = "https://www.bytereef.org/software/mpdecimal/releases/mpdecimal-${version}.tar.gz";
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
      file = tvp.packages.file;
      bash = constructionTool "bash";
      coreutils = constructionTool "coreutils";
      pkgConfig = constructionTool "pkgConfig";
      gnumake = constructionTool "make";
      gnutar = constructionTool "tar";
      python = constructionTool "python";
      binutils = constructionTool "binutils";
      patchelf = constructionTool "patchelf";
      sed = constructionTool "sed";
      grep = constructionTool "grep";
      gawk = constructionTool "gawk";
      diffutils = constructionTool "diffutils";
      findutils = constructionTool "findutils";
      gzip = constructionTool "gzip";
    };
    opts = {
      "linkWithCC" = true;
      "preparation" = {
        "documentedData" = {
          "tests/gettests.bat" = {
            "magic" = "404543484f204f46";
            "mode" = 493;
            "sha256" = "035a368e491a058662cd79736c69526af12362900544d2a8b241ae3d4b088945";
          };
        };
        "libtoolAnchors" = { };
        "selections" = [
          "configure"
          "config.sub"
          "config.guess"
          "install-sh"
          "tests"
          "tests++"
        ];
        "shellFragments" = { };
      };
    };
  };
}

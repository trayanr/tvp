# Complete ordinary OpenSSL 4 definitions.
{
  tvp,
  tvpLib,
  candidate,
  constructionTool,
}:
tvpLib.packages.mkDefs {
  "4.0.0" = {
    constructor = tvp.builder;
    builder = ./build-4.0.0.nix;
    base = (
      candidate.withHardening {
        defaults = [
          "bindnow"
          "fortify"
          "format"
          "pic"
          "relro"
          "stackprotector"
          "strictoverflow"
        ];
        disable = [ ];
      }
    );
    source =
      { version, sha256 }:
      import <nix/fetchurl.nix> {
        url = "https://github.com/openssl/openssl/releases/download/openssl-${version}/openssl-${version}.tar.gz";
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
      testPatchTool = constructionTool "patch";
      buildPerl = tvp.packages.perl_5;
      testCmake = tvp.packages.cmake;
      perl = tvp.packages.perl_5;
      runtimeCoreutils = tvp.packages.coreutils;
      runtimeSed = tvp.packages.gnused;
      runtimeGrep = tvp.packages.gnugrep;
      runtimeGawk = tvp.packages.gawk;
      runtimeFindutils = tvp.packages.findutils;
    };
    opts = {
      features = {
        shared = true;
        static = true;
        sha256 = true;
        pbkdf2 = true;
        providers = true;
        engines = false;
        engineModules = false;
        splitPkgConfig = true;
        rehash = false;
        tlsMethod = true;
        modernCli = true;
        cmake = true;
      };
    };
  };
}

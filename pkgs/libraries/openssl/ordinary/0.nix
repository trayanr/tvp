# Complete ordinary OpenSSL 0 definitions.
{
  tvp,
  tvpLib,
  candidate,
  constructionTool,
}:
tvpLib.packages.mkDefs {
  # Retained definition data for the later 0.9.8 releases that return to the
  # original warning policy. The six broken 0.9.6 releases keep legacy routing.
  "0.9.6" = {
    constructor = tvp.builder;
    builder = ./build-0.9.7.nix;
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
        url = "https://github.com/openssl/openssl/releases/download/OpenSSL_${
          builtins.replaceStrings [ "." ] [ "_" ] version
        }/openssl-${version}.tar.gz";
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
      buildPerl = tvp.packages.perl_5;
      perl = tvp.packages.perl_5;
    };
    opts = {
      features = {
        shared = true;
        static = true;
        sha256 = true;
        pbkdf2 = false;
        providers = false;
        engines = true;
        rehash = true;
        tlsMethod = false;
        modernCli = false;
        cmake = false;
      };
    };
  };
  "0.9.7" = {
    constructor = tvp.builder;
    builder = ./build-0.9.7.nix;
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
        url = "https://github.com/openssl/openssl/releases/download/OpenSSL_${
          builtins.replaceStrings [ "." ] [ "_" ] version
        }/openssl-${version}.tar.gz";
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
      buildPerl = tvp.packages.perl_5;
      perl = tvp.packages.perl_5;
    };
    opts = {
      cStandard = "gnu17";
      features = {
        shared = true;
        static = true;
        sha256 = false;
        pbkdf2 = false;
        providers = false;
        engines = true;
        rehash = true;
        tlsMethod = false;
        modernCli = false;
        cmake = false;
      };
    };
  };
  "0.9.8" = {
    constructor = tvp.builder;
    builder = ./build-0.9.7.nix;
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
        disable = [ "format" ];
      }
    );
    source =
      { version, sha256 }:
      import <nix/fetchurl.nix> {
        url = "https://github.com/openssl/openssl/releases/download/OpenSSL_${
          builtins.replaceStrings [ "." ] [ "_" ] version
        }/openssl-${version}.tar.gz";
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
      buildPerl = tvp.packages.perl_5;
      perl = tvp.packages.perl_5;
    };
    opts = {
      hardeningDisable = [ "format" ];
      features = {
        shared = true;
        static = true;
        sha256 = true;
        pbkdf2 = false;
        providers = false;
        engines = true;
        rehash = true;
        tlsMethod = false;
        modernCli = false;
        cmake = false;
      };
    };
  };
  "0.9.8s" = {
    constructor = tvp.builder;
    builder = ./build-0.9.7.nix;
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
        url = "https://github.com/openssl/openssl/releases/download/OpenSSL_${
          builtins.replaceStrings [ "." ] [ "_" ] version
        }/openssl-${version}.tar.gz";
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
      buildPerl = tvp.packages.perl_5;
      perl = tvp.packages.perl_5;
    };
    opts = {
      compileFlags = [ "-Wno-error=incompatible-pointer-types" ];
      features = {
        shared = true;
        static = true;
        sha256 = true;
        pbkdf2 = false;
        providers = false;
        engines = true;
        rehash = true;
        tlsMethod = false;
        modernCli = false;
        cmake = false;
      };
    };
  };

}

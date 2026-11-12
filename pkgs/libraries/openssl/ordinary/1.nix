# Complete ordinary OpenSSL 1 definitions.
{
  tvp,
  tvpLib,
  candidate,
  constructionTool,
}:
tvpLib.packages.mkDefs {
  "1.0.0" = {
    constructor = tvp.builder;
    builder = ./build-1.0.0.nix;
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
      runtimeCoreutils = tvp.packages.coreutils;
      runtimeSed = tvp.packages.gnused;
      runtimeGrep = tvp.packages.gnugrep;
      runtimeGawk = tvp.packages.gawk;
      runtimeFindutils = tvp.packages.findutils;
    };
    opts = {
      forceGccName = true;
      cStandard = "gnu17";
      features = {
        shared = true;
        static = true;
        sha256 = true;
        pbkdf2 = false;
        providers = false;
        engines = true;
        engineModules = true;
        splitPkgConfig = true;
        rehash = true;
        tlsMethod = false;
        modernCli = false;
        cmake = false;
      };
    };
  };
  "1.0.0i" = {
    constructor = tvp.builder;
    builder = ./build-1.0.0.nix;
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
      runtimeCoreutils = tvp.packages.coreutils;
      runtimeSed = tvp.packages.gnused;
      runtimeGrep = tvp.packages.gnugrep;
      runtimeGawk = tvp.packages.gawk;
      runtimeFindutils = tvp.packages.findutils;
    };
    opts = {
      forceGccName = true;
      features = {
        shared = true;
        static = true;
        sha256 = true;
        pbkdf2 = false;
        providers = false;
        engines = true;
        engineModules = true;
        splitPkgConfig = true;
        rehash = true;
        tlsMethod = false;
        modernCli = false;
        cmake = false;
      };
    };
  };
  "1.0.1" = {
    constructor = tvp.builder;
    builder = ./build-1.0.0.nix;
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
      runtimeCoreutils = tvp.packages.coreutils;
      runtimeSed = tvp.packages.gnused;
      runtimeGrep = tvp.packages.gnugrep;
      runtimeGawk = tvp.packages.gawk;
      runtimeFindutils = tvp.packages.findutils;
    };
    opts = {
      forceGccName = true;
      cStandard = "gnu17";
      features = {
        shared = true;
        static = true;
        sha256 = true;
        pbkdf2 = false;
        providers = false;
        engines = true;
        engineModules = true;
        splitPkgConfig = true;
        rehash = true;
        tlsMethod = false;
        modernCli = false;
        cmake = false;
      };
    };
  };
  "1.0.2p" = {
    constructor = tvp.builder;
    builder = ./build-1.0.0.nix;
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
        pbkdf2 = false;
        providers = false;
        engines = true;
        engineModules = true;
        splitPkgConfig = true;
        rehash = true;
        tlsMethod = false;
        modernCli = false;
        cmake = false;
      };
    };
  };
  "1.1.0" = {
    constructor = tvp.builder;
    builder = ./build-1.1.0.nix;
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
      runtimeCoreutils = tvp.packages.coreutils;
      runtimeSed = tvp.packages.gnused;
      runtimeGrep = tvp.packages.gnugrep;
      runtimeGawk = tvp.packages.gawk;
      runtimeFindutils = tvp.packages.findutils;
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
      buildPerl = tvpLib.packages.withConstraint {
        reason = "OpenSSL 1.1.0–1.1.0g Configure imports File::Glob qw/glob/; Perl 5.30 removed that export. Eight consumer holds remain unwaived.";
      } tvp.packages.perl_5_28;
      perl = tvpLib.packages.withConstraint {
        reason = "OpenSSL 1.1.0–1.1.0g Configure imports File::Glob qw/glob/; Perl 5.30 removed that export. Eight consumer holds remain unwaived.";
      } tvp.packages.perl_5_28;
    };
    opts = {
      features = {
        shared = true;
        static = true;
        sha256 = true;
        pbkdf2 = false;
        providers = false;
        engines = true;
        engineModules = true;
        splitPkgConfig = true;
        rehash = true;
        tlsMethod = true;
        modernCli = false;
        cmake = false;
      };
    };
  };
  "1.1.1" = {
    constructor = tvp.builder;
    builder = ./build-1.1.0.nix;
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
        providers = false;
        engines = true;
        engineModules = true;
        splitPkgConfig = true;
        rehash = true;
        tlsMethod = true;
        modernCli = false;
        cmake = false;
      };
    };
  };
  "1.0.0f" = {
    constructor = tvp.builder;
    builder = ./build-1.0.0.nix;
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
      runtimeCoreutils = tvp.packages.coreutils;
      runtimeSed = tvp.packages.gnused;
      runtimeGrep = tvp.packages.gnugrep;
      runtimeGawk = tvp.packages.gawk;
      runtimeFindutils = tvp.packages.findutils;
    };
    opts = {
      forceGccName = true;
      compileFlags = [ "-Wno-error=incompatible-pointer-types" ];
      cStandard = "gnu17";
      features = {
        shared = true;
        static = true;
        sha256 = true;
        pbkdf2 = false;
        providers = false;
        engines = true;
        engineModules = true;
        splitPkgConfig = true;
        rehash = true;
        tlsMethod = false;
        modernCli = false;
        cmake = false;
      };
    };
  };
  "1.1.1q" = {
    constructor = tvp.builder;
    builder = ./build-1.1.0.nix;
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
      runtimeCoreutils = tvp.packages.coreutils;
      runtimeSed = tvp.packages.gnused;
      runtimeGrep = tvp.packages.gnugrep;
      runtimeGawk = tvp.packages.gawk;
      runtimeFindutils = tvp.packages.findutils;
    };
    opts = {
      compileFlags = [ "-Wno-error=implicit-function-declaration" ];
      features = {
        shared = true;
        static = true;
        sha256 = true;
        pbkdf2 = true;
        providers = false;
        engines = true;
        engineModules = true;
        splitPkgConfig = true;
        rehash = true;
        tlsMethod = true;
        modernCli = false;
        cmake = false;
      };
    };
  };
  "1.1.0h" = {
    constructor = tvp.builder;
    builder = ./build-1.1.0.nix;
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
        pbkdf2 = false;
        providers = false;
        engines = true;
        engineModules = true;
        splitPkgConfig = true;
        rehash = true;
        tlsMethod = true;
        modernCli = false;
        cmake = false;
      };
    };
  };

}

{
  tvp,
  tvpLib,
  candidate,
  constructionTool,
  fetchurl,
  ncurses,
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
          "https://mirrors.kernel.org/gnu/readline/readline-${version}.tar.gz"
          "https://ftp.gnu.org/gnu/readline/readline-${version}.tar.gz"
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
      inherit ncurses;
    };
  };
  "8.0" = {
    constructor = tvp.builder;
    builder = ./build-6.0.nix;
    base = candidate.base;
    opts.pkgConfigModules = [ "readline" ];
    source =
      { version, sha256 }:
      fetchurl {
        urls = [
          "https://mirrors.kernel.org/gnu/readline/readline-${version}.tar.gz"
          "https://ftp.gnu.org/gnu/readline/readline-${version}.tar.gz"
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
      inherit ncurses;
    };
  };
  "8.2" = {
    constructor = tvp.builder;
    builder = ./build-6.0.nix;
    base = candidate.base;
    opts.pkgConfigModules = [
      "readline"
      "history"
    ];
    source =
      { version, sha256 }:
      fetchurl {
        urls = [
          "https://mirrors.kernel.org/gnu/readline/readline-${version}.tar.gz"
          "https://ftp.gnu.org/gnu/readline/readline-${version}.tar.gz"
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
      inherit ncurses;
    };
  };
  "2.1" = {
    constructor = tvp.builder;
    builder = ./build-2.1.nix;
    base = candidate.base;
    opts.commonSymbols = true;
    source =
      { version, sha256 }:
      fetchurl {
        urls = [
          "https://mirrors.kernel.org/gnu/readline/readline-${version}.tar.gz"
          "https://ftp.gnu.org/gnu/readline/readline-${version}.tar.gz"
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
      patch = constructionTool "patch";
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
      inherit ncurses;
    };
  };
  "2.2" = {
    constructor = tvp.builder;
    builder = ./build-2.1.nix;
    base = candidate.base;
    patches = [
      {
        file = ../patches/2.2-install-clobbers-libreadline.patch;
        reason = "Preserve libreadline.a while installing libhistory.a; fixed upstream in 2.2.1.";
      }
    ];
    source =
      { version, sha256 }:
      fetchurl {
        urls = [
          "https://mirrors.kernel.org/gnu/readline/readline-${version}.tar.gz"
          "https://ftp.gnu.org/gnu/readline/readline-${version}.tar.gz"
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
      patch = constructionTool "patch";
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
      inherit ncurses;
    };
  };
  "2.2.1" = {
    constructor = tvp.builder;
    builder = ./build-2.1.nix;
    base = candidate.base;
    source =
      { version, sha256 }:
      fetchurl {
        urls = [
          "https://mirrors.kernel.org/gnu/readline/readline-${version}.tar.gz"
          "https://ftp.gnu.org/gnu/readline/readline-${version}.tar.gz"
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
      patch = constructionTool "patch";
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
      inherit ncurses;
    };
  };
  "4.0" = {
    constructor = tvp.builder;
    builder = ./build-4.0.nix;
    base = candidate.base;
    source =
      { version, sha256 }:
      fetchurl {
        urls = [
          "https://mirrors.kernel.org/gnu/readline/readline-${version}.tar.gz"
          "https://ftp.gnu.org/gnu/readline/readline-${version}.tar.gz"
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
      automake = tvp.packages.automake_1;
      inherit ncurses;
    };
  };
  "4.3" = {
    constructor = tvp.builder;
    builder = ./build-4.3.nix;
    base = candidate.base;
    source =
      { version, sha256 }:
      fetchurl {
        urls = [
          "https://mirrors.kernel.org/gnu/readline/readline-${version}.tar.gz"
          "https://ftp.gnu.org/gnu/readline/readline-${version}.tar.gz"
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
      inherit ncurses;
    };
  };
  "8.3" = {
    constructor = tvp.builder;
    builder = ./build-8.3.nix;
    base = candidate.base;
    source =
      { version, sha256 }:
      fetchurl {
        urls = [
          "https://mirrors.kernel.org/gnu/readline/readline-${version}.tar.gz"
          "https://ftp.gnu.org/gnu/readline/readline-${version}.tar.gz"
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
      inherit ncurses;
    };
  };
}

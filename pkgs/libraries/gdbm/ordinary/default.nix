{
  tvp,
  tvpLib,
  candidate,
  constructionTool,
  fetchurl,
}:
tvpLib.packages.mkDefs {
  "1.8.0" = {
    constructor = tvp.builder;
    builder = ./build-1.8.0.nix;
    base = candidate.base;
    source =
      { version, sha256 }:
      fetchurl {
        urls = [
          "https://mirrors.kernel.org/gnu/gdbm/gdbm-${version}.tar.gz"
          "https://ftp.gnu.org/gnu/gdbm/gdbm-${version}.tar.gz"
        ];
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
      cStandard = "gnu89";
      preparation = {
        "selections" = [
          "configure"
          "config.sub"
          "config.guess"
          "install-sh"
          "mkinstalldirs"
          "ltmain.sh"
          "ltconfig"
        ];
        "shellFragments" = {
          "ltmain.sh" = [ "# ltmain.sh - Provide generalized library-building support services." ];
        };
        "libtoolAnchors" = {
          "ltmain.sh" = 0;
        };
        "edits" = [
          {
            "path" = "Makefile.in";
            "before" = " -o $(BINOWN) -g $(BINGRP)";
            "after" = "";
            "count" = 5;
          }
        ];
      };
    };
    patches = [
      {
        file = ../patches/1.8.0-config-sub-x86_64.patch;
        reason = "The shipped config.sub predates x86_64; accept its native CPU spelling without changing libtool's Linux rules.";
      }
    ];
  };
  "1.8.2" = {
    constructor = tvp.builder;
    builder = ./build-1.8.2.nix;
    base = candidate.base;
    source =
      { version, sha256 }:
      fetchurl {
        urls = [
          "https://mirrors.kernel.org/gnu/gdbm/gdbm-${version}.tar.gz"
          "https://ftp.gnu.org/gnu/gdbm/gdbm-${version}.tar.gz"
        ];
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
      cStandard = "gnu89";
      preparation = {
        "selections" = [
          "configure"
          "config.sub"
          "config.guess"
          "install-sh"
          "mkinstalldirs"
          "ltmain.sh"
        ];
        "shellFragments" = {
          "ltmain.sh" = [ "# ltmain.sh - Provide generalized library-building support services." ];
        };
        "libtoolAnchors" = {
          "ltmain.sh" = 1;
        };
        "edits" = [
          {
            "path" = "Makefile.in";
            "before" = " -o $(BINOWN) -g $(BINGRP)";
            "after" = "";
            "count" = 5;
          }
        ];
      };
    };
  };
  "1.9" = {
    constructor = tvp.builder;
    builder = ./build-1.9.nix;
    base = candidate.base;
    source =
      { version, sha256 }:
      fetchurl {
        urls = [
          "https://mirrors.kernel.org/gnu/gdbm/gdbm-${version}.tar.gz"
          "https://ftp.gnu.org/gnu/gdbm/gdbm-${version}.tar.gz"
        ];
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
      touchTestsuite = true;
      preparation = {
        "selections" = [
          "configure"
          "build-aux"
          "tests"
        ];
        "shellFragments" = {
          "build-aux/ltmain.sh" = [ "# Generated from ltmain.m4sh." ];
        };
        "libtoolAnchors" = {
          "build-aux/ltmain.sh" = 1;
        };
      };
    };
  };
  "1.10" = {
    constructor = tvp.builder;
    builder = ./build-1.10.nix;
    base = candidate.base;
    source =
      { version, sha256 }:
      fetchurl {
        urls = [
          "https://mirrors.kernel.org/gnu/gdbm/gdbm-${version}.tar.gz"
          "https://ftp.gnu.org/gnu/gdbm/gdbm-${version}.tar.gz"
        ];
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
          "build-aux"
          "tests"
        ];
        "shellFragments" = {
          "build-aux/ltmain.sh" = [ "# Generated from ltmain.m4sh." ];
        };
        "libtoolAnchors" = {
          "build-aux/ltmain.sh" = 1;
        };
      };
    };
  };
  "1.11" = {
    constructor = tvp.builder;
    builder = ./build-1.11.nix;
    base = candidate.base;
    source =
      { version, sha256 }:
      fetchurl {
        urls = [
          "https://mirrors.kernel.org/gnu/gdbm/gdbm-${version}.tar.gz"
          "https://ftp.gnu.org/gnu/gdbm/gdbm-${version}.tar.gz"
        ];
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
      cStandard = "gnu89";
      commonSymbols = true;
      preparation = {
        "selections" = [
          "configure"
          "build-aux"
          "tests"
        ];
        "shellFragments" = {
          "build-aux/ltmain.sh" = [ "" ];
        };
        "libtoolAnchors" = {
          "build-aux/ltmain.sh" = 1;
        };
      };
    };
  };
  "1.19" = {
    constructor = tvp.builder;
    builder = ./build-1.19.nix;
    base = candidate.base;
    source =
      { version, sha256 }:
      fetchurl {
        urls = [
          "https://mirrors.kernel.org/gnu/gdbm/gdbm-${version}.tar.gz"
          "https://ftp.gnu.org/gnu/gdbm/gdbm-${version}.tar.gz"
        ];
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
      cStandard = "gnu17";
      preparation = {
        "selections" = [
          "configure"
          "build-aux"
          "tests"
        ];
        "shellFragments" = { };
        "libtoolAnchors" = {
          "build-aux/ltmain.sh" = 1;
        };
      };
    };
  };
  "1.25" = {
    constructor = tvp.builder;
    builder = ./build-1.25.nix;
    base = candidate.base;
    source =
      { version, sha256 }:
      fetchurl {
        urls = [
          "https://mirrors.kernel.org/gnu/gdbm/gdbm-${version}.tar.gz"
          "https://ftp.gnu.org/gnu/gdbm/gdbm-${version}.tar.gz"
        ];
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
          "build-aux"
          "tests"
        ];
        "shellFragments" = { };
        "libtoolAnchors" = {
          "build-aux/ltmain.sh" = 1;
        };
      };
    };
  };
}

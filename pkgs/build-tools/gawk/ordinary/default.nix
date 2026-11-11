# Explicit older ordinary Gawk definitions; latest and retained definitions stay in the parent index.
{
  tvp,
  tvpLib,
  candidate,
  constructionTool,
}:
tvpLib.packages.mkDefs {
  "4.0.2" = {
    constructor = tvp.builder;
    builder = ./build-4.0.2.nix;
    base = candidate.base;
    source =
      { version, sha256 }:
      import <nix/fetchurl.nix> {
        url = "https://mirrors.kernel.org/gnu/gawk/gawk-${version}.tar.xz";
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
      python = constructionTool "python";
      binutils = constructionTool "binutils";
      patchelf = constructionTool "patchelf";
      sed = constructionTool "sed";
      grep = constructionTool "grep";
      gawk = constructionTool "gawk";
      diffutils = constructionTool "diffutils";
      findutils = constructionTool "findutils";
      xz = constructionTool "xz";
      perl = constructionTool "perl";
      readline = tvp.packages.readline_8;
      ncurses = tvp.packages.ncurses_6;
      checkLocales = import ../native/check-locales.nix {
        builder = tvp.builder;
        base = candidate.base;
        inherit (candidate.tools)
          bash
          coreutils
          tar
          xz
          ;
        libc = candidate.toolchain.libc;
      };
      localeProvider = tvpLib.packages.withConstraint {
        category = "construction";
        reason = "Matching source-owned target libc locale tools and C.UTF-8 data for upstream Unicode tests.";
      } candidate.toolchain.libc;
    };
  };
  "4.1.4" = {
    constructor = tvp.builder;
    builder = ./build-4.1.4.nix;
    base = candidate.base;
    source =
      { version, sha256 }:
      import <nix/fetchurl.nix> {
        url = "https://mirrors.kernel.org/gnu/gawk/gawk-${version}.tar.xz";
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
      python = constructionTool "python";
      binutils = constructionTool "binutils";
      patchelf = constructionTool "patchelf";
      sed = constructionTool "sed";
      grep = constructionTool "grep";
      gawk = constructionTool "gawk";
      diffutils = constructionTool "diffutils";
      findutils = constructionTool "findutils";
      xz = constructionTool "xz";
      perl = constructionTool "perl";
      gmp = tvp.packages.gmp_6;
      mpfr = tvp.packages.mpfr_4;
      readline = tvp.packages.readline_8;
      ncurses = tvp.packages.ncurses_6;
      checkLocales = import ../native/check-locales.nix {
        builder = tvp.builder;
        base = candidate.base;
        inherit (candidate.tools)
          bash
          coreutils
          tar
          xz
          ;
        libc = candidate.toolchain.libc;
      };
      localeProvider = tvpLib.packages.withConstraint {
        category = "construction";
        reason = "Matching source-owned target libc locale tools and C.UTF-8 data for upstream Unicode tests.";
      } candidate.toolchain.libc;
    };
  };
  "5.1.1" = {
    constructor = tvp.builder;
    builder = ./build-5.1.1.nix;
    base = candidate.base;
    source =
      { version, sha256 }:
      import <nix/fetchurl.nix> {
        url = "https://mirrors.kernel.org/gnu/gawk/gawk-${version}.tar.xz";
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
      python = constructionTool "python";
      binutils = constructionTool "binutils";
      patchelf = constructionTool "patchelf";
      sed = constructionTool "sed";
      grep = constructionTool "grep";
      gawk = constructionTool "gawk";
      diffutils = constructionTool "diffutils";
      findutils = constructionTool "findutils";
      xz = constructionTool "xz";
      perl = constructionTool "perl";
      gmp = tvp.packages.gmp_6;
      mpfr = tvp.packages.mpfr_4;
      readline = tvp.packages.readline_8;
      ncurses = tvp.packages.ncurses_6;
      checkLocales = import ../native/check-locales.nix {
        builder = tvp.builder;
        base = candidate.base;
        inherit (candidate.tools)
          bash
          coreutils
          tar
          xz
          ;
        libc = candidate.toolchain.libc;
      };
      localeProvider = tvpLib.packages.withConstraint {
        category = "construction";
        reason = "Matching source-owned target libc locale tools and C.UTF-8 data for upstream Unicode tests.";
      } candidate.toolchain.libc;
    };
  };
  "5.3.1" = {
    constructor = tvp.builder;
    builder = ./build-5.3.1.nix;
    base = candidate.base;
    source =
      { version, sha256 }:
      import <nix/fetchurl.nix> {
        url = "https://mirrors.kernel.org/gnu/gawk/gawk-${version}.tar.xz";
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
      python = constructionTool "python";
      binutils = constructionTool "binutils";
      patchelf = constructionTool "patchelf";
      sed = constructionTool "sed";
      grep = constructionTool "grep";
      gawk = constructionTool "gawk";
      diffutils = constructionTool "diffutils";
      findutils = constructionTool "findutils";
      xz = constructionTool "xz";
      perl = constructionTool "perl";
      gmp = tvp.packages.gmp_6;
      mpfr = tvp.packages.mpfr_4;
      readline = tvp.packages.readline_8;
      ncurses = tvp.packages.ncurses_6;
      checkLocales = import ../native/check-locales.nix {
        builder = tvp.builder;
        base = candidate.base;
        inherit (candidate.tools)
          bash
          coreutils
          tar
          xz
          ;
        libc = candidate.toolchain.libc;
      };
      localeProvider = tvpLib.packages.withConstraint {
        category = "construction";
        reason = "Matching source-owned target libc locale tools and C.UTF-8 data for upstream Unicode tests.";
      } candidate.toolchain.libc;
    };
  };
}

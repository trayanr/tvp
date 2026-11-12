# Complete native definition data at source compatibility boundaries.
{
  pkgs,
  tvp,
  tvpLib,
  candidate,
  constructionTool,
}:
tvpLib.packages.mkDefs {
  "3.0.2" = {
    constructor = tvp.builder;
    builder = ./build-3.0.0.nix;
    base = candidate.base;
    source = import ./source.nix { inherit (pkgs) fetchurl; };
    testContext =
      package:
      tvpLib.tests.fromPackage {
        builder = tvp.builder;
        inherit package;
      };
    helpers = {
      inherit tvp;
    };
    opts = {
      testFixtureRelinks = true;
      compileFlags = [
        "-std=gnu17"
        "-Wno-error=implicit-function-declaration"
        "-DUSE_INTERP_RESULT"
        "-fcommon"
      ];
      configureIsExecutable = false;
      hardeningDisable = [ "format" ];
    };
    patches = [
      {
        file = ../patches/3.0.1-unsigned-typedef.patch;
        reason = "Retain the original3.0.1 typedef repair for3.0.2: qualifying the signed typedef with unsigned is invalid C; use the original underlying unsigned long long type.";
      }
    ];
    deps = {
      bash = constructionTool "bash";
      coreutils = constructionTool "coreutils";
      pkgConfig = constructionTool "pkgConfig";
      gnumake = constructionTool "make";
      gnutar = constructionTool "tar";
      gzip = constructionTool "gzip";
      findutils = constructionTool "findutils";
      sed = constructionTool "sed";
      grep = constructionTool "grep";
      gawk = constructionTool "gawk";
      diffutils = constructionTool "diffutils";
      patch = constructionTool "patch";
      python = constructionTool "python";
      binutils = constructionTool "binutils";
      patchelf = constructionTool "patchelf";
      tcl = tvp.packages.tcl_8;
      readline = tvp.packages.readline_8;
      testZlib = tvp.packages.zlib_1;
    };
  };
  "3.0.7" = {
    constructor = tvp.builder;
    builder = ./build-3.0.0.nix;
    base = candidate.base;
    source = import ./source.nix { inherit (pkgs) fetchurl; };
    testContext =
      package:
      tvpLib.tests.fromPackage {
        builder = tvp.builder;
        inherit package;
      };
    helpers = {
      inherit tvp;
    };
    opts = {
      testFixtureRelinks = true;
      compileFlags = [
        "-std=gnu17"
        "-Wno-error=implicit-function-declaration"
        "-Wno-error=implicit-int"
        "-DUSE_INTERP_RESULT"
        "-fcommon"
      ];
      configureIsExecutable = false;
      hardeningDisable = [ "format" ];
    };
    patches = [ ];
    deps = {
      bash = constructionTool "bash";
      coreutils = constructionTool "coreutils";
      pkgConfig = constructionTool "pkgConfig";
      gnumake = constructionTool "make";
      gnutar = constructionTool "tar";
      gzip = constructionTool "gzip";
      findutils = constructionTool "findutils";
      sed = constructionTool "sed";
      grep = constructionTool "grep";
      gawk = constructionTool "gawk";
      diffutils = constructionTool "diffutils";
      patch = constructionTool "patch";
      python = constructionTool "python";
      binutils = constructionTool "binutils";
      patchelf = constructionTool "patchelf";
      tcl = tvp.packages.tcl_8;
      readline = tvp.packages.readline_8;
      testZlib = tvp.packages.zlib_1;
    };
  };
  "3.3.0" = {
    constructor = tvp.builder;
    builder = ./build-3.0.0.nix;
    base = candidate.base;
    source = import ./source.nix { inherit (pkgs) fetchurl; };
    testContext =
      package:
      tvpLib.tests.fromPackage {
        builder = tvp.builder;
        inherit package;
      };
    helpers = {
      inherit tvp;
    };
    opts = {
      testFixtureRelinks = true;
      compileFlags = [
        "-std=gnu17"
        "-Wno-error=implicit-function-declaration"
        "-DUSE_INTERP_RESULT"
        "-fcommon"
      ];
      configureIsExecutable = false;
      hardeningDisable = [ "format" ];
      pkgConfigMajorMinor = true;
    };
    patches = [ ];
    deps = {
      bash = constructionTool "bash";
      coreutils = constructionTool "coreutils";
      pkgConfig = constructionTool "pkgConfig";
      gnumake = constructionTool "make";
      gnutar = constructionTool "tar";
      gzip = constructionTool "gzip";
      findutils = constructionTool "findutils";
      sed = constructionTool "sed";
      grep = constructionTool "grep";
      gawk = constructionTool "gawk";
      diffutils = constructionTool "diffutils";
      patch = constructionTool "patch";
      python = constructionTool "python";
      binutils = constructionTool "binutils";
      patchelf = constructionTool "patchelf";
      tcl = tvp.packages.tcl_8;
      readline = tvp.packages.readline_8;
      testZlib = tvp.packages.zlib_1;
    };
  };
  "3.3.8" = {
    constructor = tvp.builder;
    builder = ./build-3.0.0.nix;
    base = candidate.base;
    source = import ./source.nix { inherit (pkgs) fetchurl; };
    testContext =
      package:
      tvpLib.tests.fromPackage {
        builder = tvp.builder;
        inherit package;
      };
    helpers = {
      inherit tvp;
    };
    opts = {
      testFixtureRelinks = true;
      compileFlags = [
        "-std=gnu17"
        "-Wno-error=implicit-function-declaration"
        "-DUSE_INTERP_RESULT"
        "-fcommon"
      ];
      configureIsExecutable = false;
      hardeningDisable = [ "format" ];
      pkgConfigMajorMinor = true;
    };
    patches = [ ];
    deps = {
      bash = constructionTool "bash";
      coreutils = constructionTool "coreutils";
      pkgConfig = constructionTool "pkgConfig";
      gnumake = constructionTool "make";
      gnutar = constructionTool "tar";
      gzip = constructionTool "gzip";
      findutils = constructionTool "findutils";
      sed = constructionTool "sed";
      grep = constructionTool "grep";
      gawk = constructionTool "gawk";
      diffutils = constructionTool "diffutils";
      patch = constructionTool "patch";
      python = constructionTool "python";
      binutils = constructionTool "binutils";
      patchelf = constructionTool "patchelf";
      tcl = tvp.packages.tcl_8;
      readline = tvp.packages.readline_8;
      testZlib = tvp.packages.zlib_1;
    };
  };
  "3.3.14" = {
    constructor = tvp.builder;
    builder = ./build-3.0.0.nix;
    base = candidate.base;
    source = import ./source.nix { inherit (pkgs) fetchurl; };
    testContext =
      package:
      tvpLib.tests.fromPackage {
        builder = tvp.builder;
        inherit package;
      };
    helpers = {
      inherit tvp;
    };
    opts = {
      testFixtureRelinks = true;
      compileFlags = [
        "-std=gnu17"
        "-Wno-error=implicit-function-declaration"
        "-DUSE_INTERP_RESULT"
        "-fcommon"
      ];
      configureIsExecutable = false;
      hardeningDisable = [ "format" ];
      pkgConfigMajorMinor = true;
    };
    patches = [ ];
    deps = {
      bash = constructionTool "bash";
      coreutils = constructionTool "coreutils";
      pkgConfig = constructionTool "pkgConfig";
      gnumake = constructionTool "make";
      gnutar = constructionTool "tar";
      gzip = constructionTool "gzip";
      findutils = constructionTool "findutils";
      sed = constructionTool "sed";
      grep = constructionTool "grep";
      gawk = constructionTool "gawk";
      diffutils = constructionTool "diffutils";
      patch = constructionTool "patch";
      python = constructionTool "python";
      binutils = constructionTool "binutils";
      patchelf = constructionTool "patchelf";
      tcl = tvp.packages.tcl_8;
      readline = tvp.packages.readline_8;
      testZlib = tvp.packages.zlib_1;
    };
  };
  "3.7.6" = {
    constructor = tvp.builder;
    builder = ./build-3.0.0.nix;
    base = candidate.base;
    source = import ./source.nix { inherit (pkgs) fetchurl; };
    testContext =
      package:
      tvpLib.tests.fromPackage {
        builder = tvp.builder;
        inherit package;
      };
    helpers = {
      inherit tvp;
    };
    opts = {
      testFixtureRelinks = false;
      compileFlags = [ "-std=gnu17" ];
    };
    patches = [ ];
    deps = {
      bash = constructionTool "bash";
      coreutils = constructionTool "coreutils";
      pkgConfig = constructionTool "pkgConfig";
      gnumake = constructionTool "make";
      gnutar = constructionTool "tar";
      gzip = constructionTool "gzip";
      findutils = constructionTool "findutils";
      sed = constructionTool "sed";
      grep = constructionTool "grep";
      gawk = constructionTool "gawk";
      diffutils = constructionTool "diffutils";
      patch = constructionTool "patch";
      python = constructionTool "python";
      binutils = constructionTool "binutils";
      patchelf = constructionTool "patchelf";
      tcl = tvp.packages.tcl_8;
      readline = tvp.packages.readline_8;
      testZlib = tvp.packages.zlib_1;
    };
  };
  "3.46.0" = {
    constructor = tvp.builder;
    builder = ./build-3.0.0.nix;
    base = candidate.base;
    source = import ./source.nix { inherit (pkgs) fetchurl; };
    testContext =
      package:
      tvpLib.tests.fromPackage {
        builder = tvp.builder;
        inherit package;
      };
    helpers = {
      inherit tvp;
    };
    opts = {
      testFixtureRelinks = false;
    };
    patches = [ ];
    deps = {
      bash = constructionTool "bash";
      coreutils = constructionTool "coreutils";
      pkgConfig = constructionTool "pkgConfig";
      gnumake = constructionTool "make";
      gnutar = constructionTool "tar";
      gzip = constructionTool "gzip";
      findutils = constructionTool "findutils";
      sed = constructionTool "sed";
      grep = constructionTool "grep";
      gawk = constructionTool "gawk";
      diffutils = constructionTool "diffutils";
      patch = constructionTool "patch";
      python = constructionTool "python";
      binutils = constructionTool "binutils";
      patchelf = constructionTool "patchelf";
      tcl = tvp.packages.tcl_8;
      readline = tvp.packages.readline_8;
      testZlib = tvp.packages.zlib_1;
    };
  };
}

# Complete native definition data at test-source portability boundaries.
# Ordered procedures and providers remain independent and unchanged.
{
  pkgs,
  tvp,
  tvpLib,
  candidate,
  constructionTool,
}:
tvpLib.packages.mkDefs {
  # Upstream sorts only journal-membership assertions from 3.0.8.
  "3.0.8" = {
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
  # Upstream direct expression-error reference; numeric nan tests begin.
  "3.5.9" = {
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
      compileFlags = [
        "-std=gnu17"
        "-DUSE_INTERP_RESULT"
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
  # Return after standalone 3.6.2: original options, new nan source context.
  "3.6.3" = {
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
      compileFlags = [
        "-std=gnu17"
        "-DUSE_INTERP_RESULT"
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
  # nan-4.20 acquires a numeric infinity expectation.
  "3.6.18" = {
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
      compileFlags = [
        "-std=gnu17"
      ];
      configureIsExecutable = false;
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
  # Upstream owns nan normalization and the types3 string construction.
  "3.7.7" = {
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
}

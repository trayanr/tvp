# Native definition data. Every selected procedure remains complete and independent.
{
  pkgs,
  tvp,
  tvpLib,
  candidate,
  constructionTool,
  defs,
}:
let
  migrated = pkgs.lib.mapAttrs (_: definition: {
    name = definition.name;
    constructor = tvp.builder;
    builder =
      if definition.builder == ../build-3.48.0.nix then ./build-3.48.0.nix else ./build-3.0.0.nix;
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
    opts =
      (definition.opts or { })
      // pkgs.lib.optionalAttrs (definition.builder == ../build-3.0.0.nix) {
        testFixtureRelinks = pkgs.lib.versionOlder definition.name "3.5.7";
      }
      // pkgs.lib.optionalAttrs (pkgs.lib.versionOlder definition.name "3.6.10") {
        # 3.6.10 replaced Tcl_Interp.result access with public result functions.
        # Tcl8 retains that ABI behind this compatibility macro.
        compileFlags =
          (definition.opts.compileFlags or [ ])
          ++ [ "-DUSE_INTERP_RESULT" ]
          ++ pkgs.lib.optional (pkgs.lib.versionOlder definition.name "3.5.6") "-fcommon";
      };
    patches = definition.patches or [ ];
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
  }) defs;
  # Native source/launcher boundaries preserve the retained definition table.
  compatibility = tvpLib.packages.mkDefs {
    "3.2.3" = {
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
    "3.2.5" = {
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
    "3.5.6" = {
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
    "3.5.7" = {
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
    "3.6.7" = {
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
    "3.6.12" = {
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
  };
  runtimeCompatibility = import ./runtime-compatibility-definitions.nix {
    inherit
      pkgs
      tvp
      tvpLib
      candidate
      constructionTool
      ;
  };
  testPortability = import ./test-portability-definitions.nix {
    inherit
      pkgs
      tvp
      tvpLib
      candidate
      constructionTool
      ;
  };
  testPortabilityPatches = import ./test-portability-patches.nix { inherit (pkgs) lib; };
  runtimePatches = import ./runtime-patches.nix { inherit (pkgs) lib; };
in
pkgs.lib.mapAttrs (
  name: definition:
  definition
  // {
    patches = (definition.patches or [ ]) ++ runtimePatches name;
    opts = (definition.opts or { }) // {
      testPatches = tvpLib.packages.checkPatches "sqlite.${name}.testPatches" (
        pkgs.lib.optionals
          (builtins.elem name [
            "3.6.7"
            "3.6.10"
            "3.6.11"
          ])
          [
            {
              file = ../patches/3.6.7-test-async-dlsym.patch;
              reason = "Only src/test_async.c: match VFS xDlSym callback type; upstream fixed this test adapter in 3.6.12.";
            }
          ]
        ++ testPortabilityPatches name
      );
    };
  }
) (migrated // compatibility // runtimeCompatibility // testPortability)

{ pkgs, tvp }:
let
  tvpLib = tvp.lib;

  defs = tvpLib.packages.mkDefs {
    "3.6.4" = {
      builder = ./build-3.0.0.nix;
      base = tvp.bases.default;
      deps = {
        tcl = tvp.packages.tcl_8;
        readline = tvp.packages.readline_8;
      };
      # Native Lemon declarations predate C23; keep all generator and package tests.
      opts = {
        compileFlags = [ "-std=gnu17" ];
        configureIsExecutable = false;
        hardeningDisable = [ "format" ];
      };
    };

    "3.1.1" = {
      builder = ./build-3.0.0.nix;
      base = tvp.bases.default;
      deps = {
        tcl = tvp.packages.tcl_8;
        readline = tvp.packages.readline_8;
      };
      # Native Lemon declarations predate C23; keep all generator and package tests.
      opts = {
        compileFlags = [
          "-std=gnu17"
          "-Wno-error=implicit-function-declaration"
        ];
        configureIsExecutable = false;
        hardeningDisable = [ "format" ];
        pkgConfigMajorMinor = true;
        reportedVersion = "3.1.1beta";
      };
    };

    "3.1.0" = {
      builder = ./build-3.0.0.nix;
      base = tvp.bases.default;
      deps = {
        tcl = tvp.packages.tcl_8;
        readline = tvp.packages.readline_8;
      };
      # Native Lemon declarations predate C23; keep all generator and package tests.
      opts = {
        # Lemon's preprocess_input omitted its return type until 3.1.1.
        compileFlags = [
          "-std=gnu17"
          "-Wno-error=implicit-function-declaration"
          "-Wno-error=implicit-int"
        ];
        configureIsExecutable = false;
        hardeningDisable = [ "format" ];
        pkgConfigMajorMinor = true;
        reportedVersion = "3.1.0alpha";
      };
    };

    "3.0.1" = {
      builder = ./build-3.0.0.nix;
      base = tvp.bases.default;
      deps = {
        tcl = tvp.packages.tcl_8;
        readline = tvp.packages.readline_8;
      };
      # Native Lemon declarations predate C23; keep all generator and package tests.
      opts = {
        compileFlags = [
          "-std=gnu17"
          "-Wno-error=implicit-function-declaration"
        ];
        configureIsExecutable = false;
        hardeningDisable = [ "format" ];
      };
      patches = [
        {
          file = ./patches/3.0.1-unsigned-typedef.patch;
          reason = "INTPTR_TYPE is defined as sqlite_int64, so `typedef unsigned INTPTR_TYPE uptr` qualifies a typedef name and no translation unit compiles. Restores the `long long` 3.0.0 used; 3.0.4 fixed it differently, with a separate UINTPTR_TYPE.";
        }
      ];
    };

    "3.0.4" = {
      builder = ./build-3.0.0.nix;
      base = tvp.bases.default;
      deps = {
        tcl = tvp.packages.tcl_8;
        readline = tvp.packages.readline_8;
      };
      # Native Lemon declarations predate C23; keep all generator and package tests.
      opts = {
        # Lemon's preprocess_input omitted its return type until 3.1.1.
        compileFlags = [
          "-std=gnu17"
          "-Wno-error=implicit-function-declaration"
          "-Wno-error=implicit-int"
        ];
        configureIsExecutable = false;
        hardeningDisable = [ "format" ];
      };
      patches = [
        {
          file = ./patches/3.0.4-nested-static-declaration.patch;
          reason = "btree.c forward-declares checkReadLocks as static inside sqlite3BtreeCursor's body, which is not a valid storage class at block scope. Upstream hoisted the same declaration to file scope in 3.0.6.";
        }
      ];
    };

    "3.0.0" = {
      builder = ./build-3.0.0.nix;
      base = tvp.bases.default;
      deps = {
        tcl = tvp.packages.tcl_8;
        readline = tvp.packages.readline_8;
      };
      # Native Lemon declarations predate C23; keep all generator and package tests.
      opts = {
        compileFlags = [
          "-std=gnu17"
          "-Wno-error=implicit-function-declaration"
        ];
        configureIsExecutable = false;
        hardeningDisable = [ "format" ];
      };
    };

    "3.1.2" = {
      builder = ./build-3.0.0.nix;
      base = tvp.bases.default;
      deps = {
        tcl = tvp.packages.tcl_8;
        readline = tvp.packages.readline_8;
      };
      # Native Lemon declarations predate C23; keep all generator and package tests.
      opts = {
        compileFlags = [
          "-std=gnu17"
          "-Wno-error=implicit-function-declaration"
        ];
        configureIsExecutable = false;
        hardeningDisable = [ "format" ];
        pkgConfigMajorMinor = true;
      };
    };

    "3.6.11" = {
      builder = ./build-3.0.0.nix;
      base = tvp.bases.default;
      deps = {
        tcl = tvp.packages.tcl_8;
        readline = tvp.packages.readline_8;
      };
      # Native Lemon declarations predate C23; keep all generator and package tests.
      opts = {
        compileFlags = [ "-std=gnu17" ];
        configureIsExecutable = false;
      };
      patches = [
        {
          file = ./patches/3.6.11-install-before-relink.patch;
          reason = "install depends on the libsqlite3.la build target rather than lib_install, so tcl_install relinks libtclsqlite3 against an -lsqlite3 that is not in libdir yet. Upstream made the same substitution in 3.6.12.";
        }
      ];
    };

    "3.6.14" = {
      builder = ./build-3.0.0.nix;
      base = tvp.bases.default;
      deps = {
        tcl = tvp.packages.tcl_8;
        readline = tvp.packages.readline_8;
      };
      # Native Lemon declarations predate C23; keep all generator and package tests.
      opts = {
        compileFlags = [ "-std=gnu17" ];
        configureIsExecutable = false;
      };
      patches = [
        {
          file = ./patches/3.6.14-stale-configure-version.patch;
          reason = "Upstream bumped VERSION without regenerating configure, and configure aborts when the two disagree. Sets the two version strings regeneration would have set.";
        }
      ];
    };

    "3.6.16.1" = {
      builder = ./build-3.0.0.nix;
      base = tvp.bases.default;
      deps = {
        tcl = tvp.packages.tcl_8;
        readline = tvp.packages.readline_8;
      };
      # Native Lemon declarations predate C23; keep all generator and package tests.
      opts = {
        compileFlags = [ "-std=gnu17" ];
        configureIsExecutable = false;
      };
      patches = [
        {
          file = ./patches/3.6.16.1-stale-configure-version.patch;
          reason = "Upstream bumped VERSION without regenerating configure, and configure aborts when the two disagree. Sets the two version strings regeneration would have set.";
        }
      ];
    };

    "3.6.10" = {
      builder = ./build-3.0.0.nix;
      base = tvp.bases.default;
      deps = {
        tcl = tvp.packages.tcl_8;
        readline = tvp.packages.readline_8;
      };
      # Native Lemon declarations predate C23; keep all generator and package tests.
      opts = {
        compileFlags = [ "-std=gnu17" ];
        configureIsExecutable = false;
      };
    };

    "3.7.0" = {
      builder = ./build-3.0.0.nix;
      # Native Lemon declarations predate C23; keep all generator and package tests.
      opts.compileFlags = [ "-std=gnu17" ];
      base = tvp.bases.default;
      deps = {
        tcl = tvp.packages.tcl_8;
        readline = tvp.packages.readline_8;
      };
    };

    "3.0.3" = {
      builder = ./build-3.0.0.nix;
      base = tvp.bases.default;
      deps = {
        tcl = tvp.packages.tcl_8;
        readline = tvp.packages.readline_8;
      };
      # Native Lemon declarations predate C23; keep all generator and package tests.
      opts = {
        # Lemon's preprocess_input omitted its return type until 3.1.1.
        compileFlags = [
          "-std=gnu17"
          "-Wno-error=implicit-function-declaration"
          "-Wno-error=implicit-int"
        ];
        configureIsExecutable = false;
        hardeningDisable = [ "format" ];
      };
      patches = [
        {
          file = ./patches/3.0.1-unsigned-typedef.patch;
          reason = "INTPTR_TYPE is defined as sqlite_int64, so `typedef unsigned INTPTR_TYPE uptr` qualifies a typedef name and no translation unit compiles. Restores the `long long` 3.0.0 used; 3.0.4 fixed it differently, with a separate UINTPTR_TYPE.";
        }
      ];
    };

    "3.0.6" = {
      builder = ./build-3.0.0.nix;
      base = tvp.bases.default;
      deps = {
        tcl = tvp.packages.tcl_8;
        readline = tvp.packages.readline_8;
      };
      # Native Lemon declarations predate C23; keep all generator and package tests.
      opts = {
        # Lemon's preprocess_input omitted its return type until 3.1.1.
        compileFlags = [
          "-std=gnu17"
          "-Wno-error=implicit-function-declaration"
          "-Wno-error=implicit-int"
        ];
        configureIsExecutable = false;
        hardeningDisable = [ "format" ];
      };
    };

    "3.19.0" = {
      builder = ./build-3.0.0.nix;
      base = tvp.bases.default;
      deps = {
        tcl = tvp.packages.tcl_8;
        readline = tvp.packages.readline_8;
      };
    };

    "3.4.2" = {
      builder = ./build-3.0.0.nix;
      base = tvp.bases.default;
      deps = {
        tcl = tvp.packages.tcl_8;
        readline = tvp.packages.readline_8;
      };
      # Native Lemon declarations predate C23; keep all generator and package tests.
      opts = {
        compileFlags = [ "-std=gnu17" ];
        configureIsExecutable = false;
        hardeningDisable = [ "format" ];
        pkgConfigMajorMinor = true;
      };
    };
    "3.6.2" = {
      builder = ./build-3.0.0.nix;
      base = tvp.bases.default;
      deps = {
        tcl = tvp.packages.tcl_8;
        readline = tvp.packages.readline_8;
      };
      # Native Lemon declarations predate C23; keep all generator and package tests.
      opts = {
        # sqlite3PageMalloc omits its parameter type only in this release.
        compileFlags = [
          "-std=gnu17"
          "-Wno-error=implicit-int"
        ];
        configureIsExecutable = false;
        hardeningDisable = [ "format" ];
        pkgConfigMajorMinor = true;
      };
    };

    "3.48.0" = {
      builder = ./build-3.48.0.nix;
      base = tvp.bases.default;
      deps = {
        tcl = tvp.packages.tcl_8;
        readline = tvp.packages.readline_8;
      };
    };
  };

  versionTable = tvpLib.packages.mkTable (import ./3.nix { inherit defs; });

  pname = "sqlite";

  packageArgs = {
    testDeps.pkg-config = tvp.packages.pkg-config;
    infra = {
      inherit (pkgs) lib fetchurl;
    };
    inherit pname;
    inherit versionTable;

    extraArgs = {
      mkTests = pkgs.lib.makeOverridable (
        { pkgs }:
        sqlite:
        import ./tests {
          inherit pkgs tvpLib sqlite;
          pkg-config = sqlite.tvp.declaredTestDependencies.pkg-config;
        }
      ) { inherit pkgs; };
    };

    packageMeta = {
      upstream = {
        type = "git-tags";
        url = "https://github.com/sqlite/sqlite";

        # The tag namespace also holds branch-ish names and four spellings of
        # "release"; only version-X.Y.Z is a release.
        normalise =
          tag:
          if builtins.match "version-[0-9].*" tag != null then pkgs.lib.removePrefix "version-" tag else null;

        include = version: builtins.match "3\\..*" version != null;
      };
    };
  };

  # Retain the complete table, source, dependencies and test factory for frozen callers.
  constructionRecipe = packageArgs;
  candidate = import ../../../bases/source-gnu { };
  native = pkgs.stdenv.hostPlatform.system == "x86_64-linux";
  constructionTool =
    name:
    tvpLib.packages.withConstraint {
      category = "construction";
      reason = "Retained source-GNU ${name} host tool is independent of ordinary SQLite consumers.";
    } candidate.tools.${name};
  ownedDefs = tvpLib.packages.mkDefs {
    "3.53.4" = {
      constructor = tvp.builder;
      builder = ./native/build-3.53.4.nix;
      base = candidate.base;
      source =
        { version, sha256 }:
        pkgs.fetchurl {
          name = "sqlite-${version}.tar.gz";
          urls = [
            "https://sqlite.org/src/tarball/version-${version}/sqlite-${version}.tar.gz"
            "https://www.sqlite.org/src/tarball/sqlite-${version}.tar.gz?r=version-${version}"
            "https://sqlite.org/src/tarball/sqlite-${version}.tar.gz?r=version-${version}"
          ];
          curlOptsList = [
            "--retry"
            "12"
            "--retry-delay"
            "5"
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
        pkgConfig = constructionTool "pkgConfig";
        gnumake = constructionTool "make";
        gnutar = constructionTool "tar";
        gzip = constructionTool "gzip";
        findutils = constructionTool "findutils";
        sed = constructionTool "sed";
        grep = constructionTool "grep";
        gawk = constructionTool "gawk";
        diffutils = constructionTool "diffutils";
        python = constructionTool "python";
        binutils = constructionTool "binutils";
        patchelf = constructionTool "patchelf";
        tcl = tvp.packages.tcl_8;
        readline = tvp.packages.readline_8;
        testZlib = tvp.packages.zlib_1;
      };
    };
  };
  # Native options add exact source-compatibility boundaries while the retained
  # definitions and table remain unchanged.
  remainingDefs = import ./ordinary/definitions.nix {
    inherit
      pkgs
      tvp
      tvpLib
      candidate
      constructionTool
      defs
      ;
  };
  remainingTable = pkgs.lib.mapAttrs (
    version: entry:
    entry
    // {
      def =
        if entry.def.name == "3.4.2" && pkgs.lib.versionAtLeast version "3.5.6" then
          remainingDefs."3.5.6"
        else
          entry.def;
    }
  ) (tvpLib.packages.mkTable (import ./3.nix { defs = remainingDefs; }));
  publicArgs = packageArgs // {
    versionTable = pkgs.lib.mapAttrs (
      version: entry:
      entry
      // {
        def =
          if !native || (entry.status.level or "ok") == "broken" then
            entry.def
          else if version == "3.53.4" then
            ownedDefs."3.53.4"
          else
            remainingTable.${version}.def;
      }
    ) versionTable;
    extraArgs.mkTests =
      package:
      if package ? testContext then
        import (
          if package.version == "3.53.4" then ./tests/native-default.nix else ./tests/ordinary-default.nix
        ) { inherit pkgs tvpLib package; }
      else
        constructionRecipe.extraArgs.mkTests package;
  };
  canonical = tvpLib.packages.mkVersions publicArgs;
in
{
  recipes.${pname} = publicArgs // {
    inherit constructionRecipe;
  };
  inherit canonical;
  aliases = tvpLib.packages.mkAliases {
    inherit
      pname
      versionTable
      canonical
      ;
  };
}

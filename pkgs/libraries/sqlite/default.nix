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

  canonical = tvpLib.packages.mkVersions {
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

in
{
  inherit canonical;
  aliases = tvpLib.packages.mkAliases {
    inherit
      pname
      versionTable
      canonical
      ;
  };
}

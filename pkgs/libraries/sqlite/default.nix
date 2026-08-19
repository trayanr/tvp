{ pkgs, tvp }:
let
  tvpLib = tvp.lib;

  defs = tvpLib.packages.mkDefs {
    "3.6.4" = {
      builder = ./build-3.0.0.nix;
      base = tvp.bases.default;
      deps = {
        tcl = tvp.packages.tcl_8_5_19;
        readline = tvp.packages.readline_8_3;
      };
      opts = {
        configureIsExecutable = false;
        hardeningDisable = [ "format" ];
      };
    };

    "3.1.1" = {
      builder = ./build-3.0.0.nix;
      base = tvp.bases.default;
      deps = {
        tcl = tvp.packages.tcl_8_5_19;
        readline = tvp.packages.readline_8_3;
      };
      opts = {
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
        tcl = tvp.packages.tcl_8_5_19;
        readline = tvp.packages.readline_8_3;
      };
      opts = {
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
        tcl = tvp.packages.tcl_8_5_19;
        readline = tvp.packages.readline_8_3;
      };
      opts = {
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
        tcl = tvp.packages.tcl_8_5_19;
        readline = tvp.packages.readline_8_3;
      };
      opts = {
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
        tcl = tvp.packages.tcl_8_5_19;
        readline = tvp.packages.readline_8_3;
      };
      opts = {
        configureIsExecutable = false;
        hardeningDisable = [ "format" ];
      };
    };

    "3.1.2" = {
      builder = ./build-3.0.0.nix;
      base = tvp.bases.default;
      deps = {
        tcl = tvp.packages.tcl_8_5_19;
        readline = tvp.packages.readline_8_3;
      };
      opts = {
        configureIsExecutable = false;
        hardeningDisable = [ "format" ];
        pkgConfigMajorMinor = true;
      };
    };

    "3.6.11" = {
      builder = ./build-3.0.0.nix;
      base = tvp.bases.default;
      deps = {
        tcl = tvp.packages.tcl_8_5_19;
        readline = tvp.packages.readline_8_3;
      };
      opts = {
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
        tcl = tvp.packages.tcl_8_5_19;
        readline = tvp.packages.readline_8_3;
      };
      opts = {
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
        tcl = tvp.packages.tcl_8_5_19;
        readline = tvp.packages.readline_8_3;
      };
      opts = {
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
        tcl = tvp.packages.tcl_8_5_19;
        readline = tvp.packages.readline_8_3;
      };
      opts = {
        configureIsExecutable = false;
      };
    };

    "3.7.0" = {
      builder = ./build-3.0.0.nix;
      base = tvp.bases.default;
      deps = {
        tcl = tvp.packages.tcl_8_5_19;
        readline = tvp.packages.readline_8_3;
      };
    };

    "3.48.0" = {
      builder = ./build-3.48.0.nix;
      base = tvp.bases.default;
      deps = {
        tcl = tvp.packages.tcl_8_6_18;
        readline = tvp.packages.readline_8_3;
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
      mkTests =
        sqlite:
        import ./tests {
          inherit pkgs tvpLib sqlite;
        };
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

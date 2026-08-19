{ pkgs, tvp }:
let
  tvpLib = tvp.lib;

  defs = tvpLib.packages.mkDefs {
    "1.1.3" = {
      builder = ./build-1.0.1.nix;
      base = tvp.bases.gcc13;
      deps = { };
    };

    # 0.x writes cast-as-lvalue (`*((Byte*)buf)++`), which only gcc 4 still
    # accepts.
    "0.8" = {
      builder = ./build-0.8.nix;
      base = tvp.bases.gcc49;
      deps = { };
    };

    "1.0.1" = {
      builder = ./build-1.0.1.nix;
      base = tvp.bases.gcc13;
      deps = { };
      opts = {
        arCommand = "ar rc";
        assumeSystemHeaders = true;
        errnoHeader = true;
        prefixInstallFlag = true;
        createInstallDirs = true;
      };
    };

    # 1.2.0 and 1.2.0.1 build shared instead of static under --shared, but their
    # `all:` still links the example programs against libz.a.
    "1.2.0" = {
      builder = ./build-1.0.1.nix;
      base = tvp.bases.gcc13;
      deps = { };
      opts = {
        arCommand = "ar rc";
        assumeSystemHeaders = true;
        linkAgainstLibs = true;
      };
    };

    "1.1.2" = {
      builder = ./build-1.0.1.nix;
      base = tvp.bases.gcc13;
      deps = { };
      opts = {
        arCommand = "ar rc";
        assumeSystemHeaders = true;
      };
    };

    "1.2.0.5" = {
      builder = ./build-1.0.1.nix;
      base = tvp.bases.gcc13;
      deps = { };
      opts = {
        createManDir = true;
      };
    };

    "1.2.3.2" = {
      builder = ./build-1.0.1.nix;
      base = tvp.bases.gcc13;
      deps = { };
      patches = [
        {
          file = ./patches/1.2.3.2-installed-header-needs-largefile64.patch;
          reason = "configure appends `#define z_off_t off64_t` to the installed zlibdefs.h but puts -D_LARGEFILE64_SOURCE only in its own CFLAGS, so no consumer can include zlib.h. 1.2.3.3 stopped emitting it.";
        }
      ];
    };

    "1.2.3.4" = {
      builder = ./build-1.0.1.nix;
      base = tvp.bases.gcc13;
      deps = { };
      patches = [
        {
          file = ./patches/1.2.3.4-shared-library-not-installed.patch;
          reason = "configure drops LIBS=\"$LIBS $SHAREDLIBV\", present in 1.2.3.3 and restored in 1.2.3.5, so libz.so.1.2.3.4 is built and never installed and the libz.so.1 soname link is absent.";
        }
      ];
    };

    "1.2.4.4" = {
      builder = ./build-1.0.1.nix;
      base = tvp.bases.gcc13;
      deps = { };
      opts = {
        sharedLibDir = true;
      };
    };

    "1.2.7.2" = {
      builder = ./build-1.0.1.nix;
      base = tvp.bases.gcc13;
      deps = { };
      opts = {
        reportedVersion = "1.2.7.2-motley";
      };
    };
  };

  versionTable = tvpLib.packages.mkTable (import ./1.nix { inherit defs; });

  canonical = tvpLib.packages.mkVersions {
    infra = {
      inherit (pkgs) lib fetchurl;
    };
    pname = "zlib";
    inherit versionTable;

    extraArgs = {
      mkTests =
        zlib:
        import ./tests {
          inherit pkgs tvpLib zlib;
        };
    };

    packageMeta = {
      upstream = {
        type = "git-tags";
        url = "https://github.com/madler/zlib";

        normalise = tag: if pkgs.lib.hasPrefix "v" tag then pkgs.lib.removePrefix "v" tag else null;

        include =
          version:
          builtins.match "[0-9].*" version != null
          && !(
            pkgs.lib.hasInfix "alpha" version
            || pkgs.lib.hasInfix "beta" version
            || pkgs.lib.hasInfix "rc" version
            || pkgs.lib.hasInfix "pre" version
          );

        unavailable = [
          {
            versions = [ "1.3.1.2" ];
            reason = "Tagged but never published as a release tarball: absent from zlib.net and from fossils/, which is upstream's own archive of everything it has shipped. Only the GitHub git-archive snapshot exists, and that is a different artifact.";
          }
        ];
      };
    };
  };

  # No `zlib_1_3`: upstream shipped a release literally called 1.3, so that name
  # is canonical and an alias may not shadow it.
  aliases = {
    zlib_1 = canonical.zlib_1_3_2;
    zlib = canonical.zlib_1_3_2;
  };
in
canonical // tvpLib.packages.checkAliases { inherit canonical aliases; }

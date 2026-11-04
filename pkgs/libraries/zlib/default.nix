{ pkgs, tvp }:
let
  tvpLib = tvp.lib;

  defs = tvpLib.packages.mkDefs {
    "1.1.3" = {
      builder = ./build-1.0.1.nix;
      base = tvp.bases.default;
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
      base = tvp.bases.default;
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
      base = tvp.bases.default;
      deps = { };
      opts = {
        arCommand = "ar rc";
        assumeSystemHeaders = true;
        linkAgainstLibs = true;
      };
    };

    "1.1.2" = {
      builder = ./build-1.0.1.nix;
      base = tvp.bases.default;
      deps = { };
      opts = {
        arCommand = "ar rc";
        assumeSystemHeaders = true;
      };
    };

    "1.2.0.5" = {
      builder = ./build-1.0.1.nix;
      base = tvp.bases.default;
      deps = { };
      opts = {
        createManDir = true;
      };
    };

    "1.2.3.2" = {
      builder = ./build-1.0.1.nix;
      base = tvp.bases.default;
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
      base = tvp.bases.default;
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
      base = tvp.bases.default;
      deps = { };
      opts = {
        sharedLibDir = true;
      };
    };

    "1.2.7.2" = {
      builder = ./build-1.0.1.nix;
      base = tvp.bases.default;
      deps = { };
      opts = {
        reportedVersion = "1.2.7.2-motley";
      };
    };
  };

  versionTable = tvpLib.packages.mkTable (import ./1.nix { inherit defs; });

  pname = "zlib";

  packageArgs = {
    infra = {
      inherit (pkgs) lib fetchurl;
    };
    inherit pname;
    inherit versionTable;
    testDeps = {
      pkg-config = tvp.packages.pkg-config;
      gzip = tvp.packages.gzip;
    };

    extraArgs = {
      mkTests = pkgs.lib.makeOverridable (
        { pkgs }:
        zlib:
        import ./tests {
          inherit pkgs tvpLib zlib;
          inherit (zlib.tvp.declaredTestDependencies) pkg-config gzip;
        }
      ) { inherit pkgs; };
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

  completed = tvp.bases.default;
  seed =
    reason:
    tvpLib.packages.withConstraint {
      category = "construction";
      inherit reason;
    };
  ownedDefs = tvpLib.packages.mkDefs {
    "1.3.2" = {
      constructor = tvp.builder;
      builder = ./owned/build-1.3.2.nix;
      base = completed;
      helpers = {
        inherit tvp;
      };
      deps = {
        bash = tvp.packages.bash_5;
        coreutils = seed "Completed Coreutils for build/output operations: canonical Coreutils depends on GMP and would recurse through archive and finalization prerequisites." completed.components.floor.coreutils;
        gnumake = tvp.packages.gnumake_4;
        gnutar = seed "Completed Tar for source extraction: canonical Tar depends on ACL, which shares this prerequisite library wave." completed.components.floor.gnutar;
        gzip = seed "Completed gzip for extraction and manual compression, before rebuilding archive-tool reverse dependencies." completed.components.floor.gzip;
        python = seed "Completed libc construction Python is build-only for explicit source and output operations." completed.components.libc.tvp.deps.python3Minimal;
        binutils = seed "Completed Binutils is build-only for ELF/archive inspection and stripping, without following the canonical compiler graph." completed.components.binutils;
        patchelf = seed "Completed Patchelf is build-only for ELF finalization; canonical Patchelf can require this wave's archive libraries." completed.fixupTools.patchelf;
      };
    };
  };
  publicArgs = packageArgs // {
    versionTable = versionTable // {
      "1.3.2" = versionTable."1.3.2" // {
        def = ownedDefs."1.3.2";
      };
    };
    source =
      { version, sha256 }:
      pkgs.fetchurl {
        url = "https://zlib.net/fossils/zlib-${version}.tar.gz";
        inherit sha256;
      };
    extraArgs.mkTests = pkgs.lib.makeOverridable (
      { pkgs }:
      package:
      packageArgs.extraArgs.mkTests.override { inherit pkgs; } package
      // pkgs.lib.optionalAttrs (package.version == "1.3.2") (
        import ./tests/owned.nix {
          inherit tvp tvpLib package;
          pkgs = tvpLib.tests.withBase {
            inherit pkgs;
            base.stdenv = package.stdenv;
          };
          inherit (package.tvp.declaredTestDependencies) pkg-config;
        }
      )
    ) { inherit pkgs; };
  };
  # Frozen construction selects the complete retained call and test factory.
  constructionRecipe = packageArgs;
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

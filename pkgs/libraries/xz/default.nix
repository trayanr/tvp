{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  native = pkgs.stdenv.hostPlatform.system == "x86_64-linux";
  candidate = import ../../../bases/source-gnu { };

  defs = tvpLib.packages.mkDefs {
    "5.8.4" = {
      builder = ./build-5.8.4.nix;
      base = tvp.bases.default;
      deps = { };
    };

    "5.0.0" = {
      builder = ./build-5.0.0.nix;
      base = tvp.bases.default;
      deps = { };
    };
  };

  versionTable = tvpLib.packages.mkTable (import ./5.nix { inherit defs; });

  pname = "xz";

  packageArgs = {
    infra = {
      inherit (pkgs) lib fetchurl;
    };
    inherit pname;
    inherit versionTable;
    testDeps = {
      pkg-config = tvp.packages.pkg-config;
      # Frozen construction keeps the exact retained format oracle. The public
      # ordinary factory below deliberately follows the moving xz_5_0 selector.
      referenceOlder = (tvpLib.packages.mkVersions packageArgs).xz_5_0_8;
      referenceNewer = tvp.packages.xz_5_8;
    };

    extraArgs = {
      mkTests =
        xz:
        import ./tests {
          inherit pkgs tvpLib xz;
          inherit (xz.tvp.declaredTestDependencies) pkg-config referenceOlder referenceNewer;
        };
    };

    packageMeta = {
      upstream = {
        type = "git-tags";
        url = "https://github.com/tukaani-project/xz";

        normalise = tag: if pkgs.lib.hasPrefix "v" tag then pkgs.lib.removePrefix "v" tag else null;

        include =
          version:
          builtins.match "[0-9].*" version != null
          && !(pkgs.lib.hasInfix "alpha" version || pkgs.lib.hasInfix "beta" version);

        unavailable = [
          {
            versions = [
              "5.6.0"
              "5.6.1"
            ];
            reason = "Withdrawn by upstream following CVE-2024-3094: the release tarballs carried a build-time backdoor absent from the git tree. Both are 404 on tukaani.org and on GitHub releases, so there is nothing to package and nothing TVP would put in a signed cache.";
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
  legacyDefs = tvpLib.packages.mkDefs {
    "5.8.4" = {
      constructor = tvp.builder;
      builder = ./owned/build-5.8.4.nix;
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
  ownedDefs = tvpLib.packages.mkDefs {
    "5.8.4" = {
      constructor = tvp.builder;
      builder = ./native/build-5.8.4.nix;
      base = candidate.base;
      source =
        { version, sha256 }:
        import <nix/fetchurl.nix> {
          url = "https://github.com/tukaani-project/xz/releases/download/v${version}/xz-${version}.tar.gz";
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
      # Retained source-built host tools avoid Coreutils/Tar/Perl/archive cycles.
      deps = {
        inherit (candidate.tools)
          bash
          coreutils
          gzip
          python
          binutils
          patchelf
          sed
          grep
          gawk
          diffutils
          findutils
          ;
        gnumake = candidate.tools.make;
        gnutar = candidate.tools.tar;
      };
    };
  };
  ordinaryDefs = tvpLib.packages.mkDefs {
    "5.0.0" = {
      constructor = tvp.builder;
      builder = ./ordinary/build-5.0.0.nix;
      base = candidate.base;
      source =
        { version, sha256 }:
        import <nix/fetchurl.nix> {
          url = "https://tukaani.org/xz/xz-${version}.tar.gz";
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
      # These source-owned construction tools avoid Coreutils/GMP, Tar/ACL and
      # archive-tool cycles. Python/Binutils/Patchelf inspect and finalize only;
      # Bash plus the small text tools also provide installed helper runtimes.
      deps = {
        inherit (candidate.tools)
          bash
          coreutils
          gzip
          python
          binutils
          patchelf
          sed
          grep
          gawk
          diffutils
          findutils
          ;
        less = tvp.packages.less;
        gnumake = candidate.tools.make;
        gnutar = candidate.tools.tar;
      };
    };
    "5.2.0" = {
      constructor = tvp.builder;
      builder = ./ordinary/build-5.2.0.nix;
      base = candidate.base;
      source =
        { version, sha256 }:
        import <nix/fetchurl.nix> {
          url = "https://tukaani.org/xz/xz-${version}.tar.gz";
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
      # Retained source-built host tools avoid Coreutils/Tar/Perl/archive cycles.
      deps = {
        inherit (candidate.tools)
          bash
          coreutils
          gzip
          python
          binutils
          patchelf
          sed
          grep
          gawk
          diffutils
          findutils
          ;
        gnumake = candidate.tools.make;
        gnutar = candidate.tools.tar;
      };
    };
  };
  publicArgs = packageArgs // {
    testDeps = packageArgs.testDeps // {
      referenceOlder = tvp.packages.xz_5_0;
    };
    versionTable = versionTable // {
      "5.0.0" = versionTable."5.0.0" // {
        def = ordinaryDefs."5.0.0";
      };
      "5.0.1" = versionTable."5.0.1" // {
        def = ordinaryDefs."5.0.0";
      };
      "5.0.2" = versionTable."5.0.2" // {
        def = ordinaryDefs."5.0.0";
      };
      "5.0.3" = versionTable."5.0.3" // {
        def = ordinaryDefs."5.0.0";
      };
      "5.0.4" = versionTable."5.0.4" // {
        def = ordinaryDefs."5.0.0";
      };
      "5.0.5" = versionTable."5.0.5" // {
        def = ordinaryDefs."5.0.0";
      };
      "5.0.6" = versionTable."5.0.6" // {
        def = ordinaryDefs."5.0.0";
      };
      "5.0.7" = versionTable."5.0.7" // {
        def = ordinaryDefs."5.0.0";
      };
      "5.0.8" = versionTable."5.0.8" // {
        def = ordinaryDefs."5.0.0";
      };
      "5.2.0" = versionTable."5.2.0" // {
        def = ordinaryDefs."5.2.0";
      };
      "5.2.1" = versionTable."5.2.1" // {
        def = ordinaryDefs."5.2.0";
      };
      "5.2.2" = versionTable."5.2.2" // {
        def = ordinaryDefs."5.2.0";
      };
      "5.2.3" = versionTable."5.2.3" // {
        def = ordinaryDefs."5.2.0";
      };
      "5.2.4" = versionTable."5.2.4" // {
        def = ordinaryDefs."5.2.0";
      };
      "5.2.5" = versionTable."5.2.5" // {
        def = ordinaryDefs."5.2.0";
      };
      "5.2.6" = versionTable."5.2.6" // {
        def = ordinaryDefs."5.2.0";
      };
      "5.2.7" = versionTable."5.2.7" // {
        def = ordinaryDefs."5.2.0";
      };
      "5.2.8" = versionTable."5.2.8" // {
        def = ordinaryDefs."5.2.0";
      };
      "5.2.9" = versionTable."5.2.9" // {
        def = ordinaryDefs."5.2.0";
      };
      "5.2.10" = versionTable."5.2.10" // {
        def = ordinaryDefs."5.2.0";
      };
      "5.2.11" = versionTable."5.2.11" // {
        def = ordinaryDefs."5.2.0";
      };
      "5.2.12" = versionTable."5.2.12" // {
        def = ordinaryDefs."5.2.0";
      };
      "5.2.13" = versionTable."5.2.13" // {
        def = ordinaryDefs."5.2.0";
      };
      "5.4.0" = versionTable."5.4.0" // {
        def = ordinaryDefs."5.2.0";
      };
      "5.4.1" = versionTable."5.4.1" // {
        def = ordinaryDefs."5.2.0";
      };
      "5.4.2" = versionTable."5.4.2" // {
        def = ordinaryDefs."5.2.0";
      };
      "5.4.3" = versionTable."5.4.3" // {
        def = ordinaryDefs."5.2.0";
      };
      "5.4.4" = versionTable."5.4.4" // {
        def = ordinaryDefs."5.2.0";
      };
      "5.4.5" = versionTable."5.4.5" // {
        def = ordinaryDefs."5.2.0";
      };
      "5.4.6" = versionTable."5.4.6" // {
        def = ordinaryDefs."5.2.0";
      };
      "5.4.7" = versionTable."5.4.7" // {
        def = ordinaryDefs."5.2.0";
      };
      "5.6.2" = versionTable."5.6.2" // {
        def = ordinaryDefs."5.2.0";
      };
      "5.6.3" = versionTable."5.6.3" // {
        def = ordinaryDefs."5.2.0";
      };
      "5.6.4" = versionTable."5.6.4" // {
        def = ordinaryDefs."5.2.0";
      };
      "5.8.0" = versionTable."5.8.0" // {
        def = ordinaryDefs."5.2.0";
      };
      "5.8.1" = versionTable."5.8.1" // {
        def = ordinaryDefs."5.2.0";
      };
      "5.8.2" = versionTable."5.8.2" // {
        def = ordinaryDefs."5.2.0";
      };
      "5.8.3" = versionTable."5.8.3" // {
        def = ordinaryDefs."5.2.0";
      };
      "5.8.4" = versionTable."5.8.4" // {
        def = if native then ownedDefs."5.8.4" else legacyDefs."5.8.4";
      };
    };
    source =
      { version, sha256 }:
      pkgs.fetchurl {
        url = "https://github.com/tukaani-project/xz/releases/download/v${version}/xz-${version}.tar.gz";
        inherit sha256;
      };
    extraArgs.mkTests = pkgs.lib.makeOverridable (
      {
        pkgs,
        pkg-config ? null,
        referenceOlder ? null,
        referenceNewer ? null,
      }:
      package:
      let
        dependencies =
          package.tvp.declaredTestDependencies
          // pkgs.lib.filterAttrs (_: value: value != null) {
            inherit pkg-config referenceOlder referenceNewer;
          };
      in
      (
        if
          package ? artifact
          && builtins.elem package.version [
            "5.0.0"
            "5.0.1"
            "5.0.2"
            "5.0.3"
            "5.0.4"
            "5.0.5"
            "5.0.6"
            "5.0.7"
            "5.0.8"
          ]
        then
          import ./tests/older-default.nix {
            inherit pkgs tvpLib;
            xz = package;
            inherit (dependencies) pkg-config referenceOlder referenceNewer;
          }
        else if
          package ? artifact
          && builtins.elem package.version [
            "5.2.0"
            "5.2.1"
            "5.2.2"
            "5.2.3"
            "5.2.4"
            "5.2.5"
            "5.2.6"
            "5.2.7"
            "5.2.8"
            "5.2.9"
            "5.2.10"
            "5.2.11"
            "5.2.12"
            "5.2.13"
            "5.4.0"
            "5.4.1"
            "5.4.2"
            "5.4.3"
            "5.4.4"
            "5.4.5"
            "5.4.6"
            "5.4.7"
            "5.6.2"
            "5.6.3"
            "5.6.4"
            "5.8.0"
            "5.8.1"
            "5.8.2"
            "5.8.3"
          ]
        then
          import ./tests/ordinary-default.nix {
            inherit pkgs tvpLib;
            xz = package;
            inherit (dependencies) pkg-config referenceOlder referenceNewer;
          }
        else
          import ./tests {
            inherit pkgs tvpLib;
            xz = package;
            inherit (dependencies) pkg-config referenceOlder referenceNewer;
          }
      )
      // pkgs.lib.optionalAttrs (package.version == "5.8.4") (
        import ./tests/owned.nix {
          inherit tvp tvpLib package;
          pkgs =
            if package ? testContext then
              pkgs
            else
              tvpLib.tests.withBase {
                inherit pkgs;
                base.stdenv = package.stdenv;
              };
          inherit (dependencies) pkg-config;
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

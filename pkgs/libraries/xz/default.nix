{ pkgs, tvp }:
let
  tvpLib = tvp.lib;

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
      referenceOlder = tvp.packages.xz_5_0;
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
  ownedDefs = tvpLib.packages.mkDefs {
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
  publicArgs = packageArgs // {
    versionTable = versionTable // {
      "5.8.4" = versionTable."5.8.4" // {
        def = ownedDefs."5.8.4";
      };
    };
    source =
      { version, sha256 }:
      pkgs.fetchurl {
        url = "https://github.com/tukaani-project/xz/releases/download/v${version}/xz-${version}.tar.gz";
        inherit sha256;
      };
    extraArgs.mkTests =
      package:
      packageArgs.extraArgs.mkTests package
      // pkgs.lib.optionalAttrs (package.version == "5.8.4") (
        import ./tests/owned.nix {
          inherit tvp tvpLib package;
          pkgs = tvpLib.tests.withBase {
            inherit pkgs;
            base.stdenv = package.stdenv;
          };
          inherit (package.tvp.declaredTestDependencies) pkg-config;
        }
      );
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

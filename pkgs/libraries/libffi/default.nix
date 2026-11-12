{ pkgs, tvp }:
let
  tvpLib = tvp.lib;

  defs = tvpLib.packages.mkDefs {
    "3.0.9" = {
      builder = ./build-3.0.9.nix;
      base = tvp.bases.default;
      deps = { };
    };

    "3.4.3" = {
      builder = ./build-3.4.3.nix;
      base = tvp.bases.default;
      deps = { };
      # tramp.c calls the existing int(void) function without its declaration.
      # Upstream ce077e5565366171aa1b4438749b0922fce887a4 fixed this in 3.4.5.
      # Keep the original source and warning, demoting only this GCC14 error.
      opts.cFlags = [ "-Wno-error=implicit-function-declaration" ];
    };

    "3.6.0" = {
      builder = ./build-3.0.9.nix;
      base = tvp.bases.default;
      deps = { };
      opts = {
        reportedVersion = "3.5.2";
      };
    };
  };

  versionTable = tvpLib.packages.mkTable (import ./3.nix { inherit defs; });

  pname = "libffi";

  packageArgs = {
    testDeps.pkg-config = tvp.packages.pkg-config;
    infra = {
      inherit (pkgs) lib fetchurl;
    };
    inherit pname;
    inherit versionTable;

    extraArgs = {
      mkTests =
        libffi:
        import ./tests {
          inherit pkgs tvpLib libffi;
          pkg-config = libffi.tvp.declaredTestDependencies.pkg-config;
        };
    };

    packageMeta = {
      upstream = {
        type = "git-tags";
        url = "https://github.com/libffi/libffi";

        normalise = tag: if pkgs.lib.hasPrefix "v" tag then pkgs.lib.removePrefix "v" tag else null;

        include =
          version:
          builtins.match "[0-9].*" version != null
          && !(pkgs.lib.hasInfix "rc" version || pkgs.lib.hasInfix "dev" version);

        unavailable = [
          {
            versions = [
              "3.4.0"
              "3.4.1"
            ];
            reason = "Tagged but never published as a tarball: the GitHub release for each carries no assets at all, where 3.4.2's carries one, and sourceware's archive has neither. Only git-archive snapshots exist, and that is a different artifact.";
          }
        ];
      };
    };
  };

  # Preserve the complete pre-promotion factory/table and its historical callers.
  constructionRecipe = packageArgs;
  candidate = import ../../../bases/source-gnu { };
  native = pkgs.stdenv.hostPlatform.system == "x86_64-linux";
  constructionTool =
    name:
    tvpLib.packages.withConstraint {
      category = "construction";
      reason = "Retained source-GNU ${name} is the explicit host generation, independent of the ordinary target being built.";
    } candidate.tools.${name};
  ownedDefs = tvpLib.packages.mkDefs {
    "3.8.0" = {
      constructor = tvp.builder;
      builder = ./native/build-3.8.0.nix;
      base = candidate.base;
      source =
        { version, sha256 }:
        import <nix/fetchurl.nix> {
          url = "https://github.com/libffi/libffi/releases/download/v${version}/libffi-${version}.tar.gz";
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
        python = constructionTool "python";
        binutils = constructionTool "binutils";
        patchelf = constructionTool "patchelf";
        sed = constructionTool "sed";
        grep = constructionTool "grep";
        gawk = constructionTool "gawk";
        diffutils = constructionTool "diffutils";
        findutils = constructionTool "findutils";
        gzip = constructionTool "gzip";
        dejagnu = tvpLib.packages.withConstraint {
          category = "construction";
          reason = "Retained source GCC DejaGnu/Expect/Tcl harness independently exercises libffi ABI and closures.";
        } (import ../../../bootstrap/source-gcc-test-harness.nix { }).dejagnu;

      };
    };
  };
  defaultTestPkgs = pkgs;
  ordinaryDefs = import ./ordinary {
    inherit
      tvp
      tvpLib
      candidate
      constructionTool
      ;
    inherit (pkgs) fetchurl;
  };
  publicArgs = packageArgs // {
    versionTable = versionTable // {
      "3.0.9" = versionTable."3.0.9" // {
        def = if native then ordinaryDefs."3.0.9" else versionTable."3.0.9".def;
      };
      "3.0.10" = versionTable."3.0.10" // {
        def = if native then ordinaryDefs."3.0.10" else versionTable."3.0.10".def;
      };
      "3.0.11" = versionTable."3.0.11" // {
        def = if native then ordinaryDefs."3.0.11" else versionTable."3.0.11".def;
      };
      "3.0.12" = versionTable."3.0.12" // {
        def = if native then ordinaryDefs."3.0.12" else versionTable."3.0.12".def;
      };
      "3.0.13" = versionTable."3.0.13" // {
        def = if native then ordinaryDefs."3.0.12" else versionTable."3.0.13".def;
      };
      "3.1" = versionTable."3.1" // {
        def = if native then ordinaryDefs."3.1" else versionTable."3.1".def;
      };
      "3.2" = versionTable."3.2" // {
        def = if native then ordinaryDefs."3.1" else versionTable."3.2".def;
      };
      "3.2.1" = versionTable."3.2.1" // {
        def = if native then ordinaryDefs."3.1" else versionTable."3.2.1".def;
      };
      "3.3" = versionTable."3.3" // {
        def = if native then ordinaryDefs."3.3" else versionTable."3.3".def;
      };
      "3.4.2" = versionTable."3.4.2" // {
        def = if native then ordinaryDefs."3.3" else versionTable."3.4.2".def;
      };
      "3.4.3" = versionTable."3.4.3" // {
        def = if native then ordinaryDefs."3.4.3" else versionTable."3.4.3".def;
      };
      "3.4.4" = versionTable."3.4.4" // {
        def = if native then ordinaryDefs."3.4.3" else versionTable."3.4.4".def;
      };
      "3.4.5" = versionTable."3.4.5" // {
        def = if native then ordinaryDefs."3.3" else versionTable."3.4.5".def;
      };
      "3.4.6" = versionTable."3.4.6" // {
        def = if native then ordinaryDefs."3.3" else versionTable."3.4.6".def;
      };
      "3.4.7" = versionTable."3.4.7" // {
        def = if native then ordinaryDefs."3.3" else versionTable."3.4.7".def;
      };
      "3.4.8" = versionTable."3.4.8" // {
        def = if native then ordinaryDefs."3.3" else versionTable."3.4.8".def;
      };
      "3.5.0" = versionTable."3.5.0" // {
        def = if native then ordinaryDefs."3.5.0" else versionTable."3.5.0".def;
      };
      "3.5.1" = versionTable."3.5.1" // {
        def = if native then ordinaryDefs."3.5.0" else versionTable."3.5.1".def;
      };
      "3.5.2" = versionTable."3.5.2" // {
        def = if native then ordinaryDefs."3.5.0" else versionTable."3.5.2".def;
      };
      "3.6.0" = versionTable."3.6.0" // {
        def = if native then ordinaryDefs."3.6.0" else versionTable."3.6.0".def;
      };
      "3.7.0" = versionTable."3.7.0" // {
        def = if native then ordinaryDefs."3.5.0" else versionTable."3.7.0".def;
      };
      "3.7.1" = versionTable."3.7.1" // {
        def = if native then ordinaryDefs."3.5.0" else versionTable."3.7.1".def;
      };

      "3.8.0" = versionTable."3.8.0" // {
        def = if native then ownedDefs."3.8.0" else versionTable."3.8.0".def;
      };
    };
    extraArgs.mkTests = pkgs.lib.makeOverridable (
      args@{
        pkgs ? defaultTestPkgs,
      }:
      package:
      if args ? pkgs then
        import ./tests {
          inherit pkgs tvpLib;
          libffi = package;
          pkg-config = package.tvp.declaredTestDependencies.pkg-config;
        }
      else if package ? testContext && package.specification ? features then
        import ./tests/ordinary.nix {
          inherit
            pkgs
            tvp
            tvpLib
            package
            ;
        }
      else if package ? testContext then
        import ./tests/native-default.nix { inherit pkgs tvpLib package; }
      else
        constructionRecipe.extraArgs.mkTests package
    ) { };
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

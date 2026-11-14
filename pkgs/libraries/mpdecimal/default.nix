{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  defs = tvpLib.packages.mkDefs {
    "4.0.0" = {
      builder = ./build-4.0.0.nix;
      base = tvp.bases.default;
      deps = { };
      # 4.0.0 inherits LD=ld but uses compiler-driver flags for shared links.
      opts.linkWithCC = true;
    };
    "4.0.1" = {
      builder = ./build-4.0.0.nix;
      base = tvp.bases.default;
      deps = { };
    };
  };
  pname = "mpdecimal";
  versionTable = tvpLib.packages.mkTable [
    {
      def = defs."4.0.0";
      releases = {
        "4.0.0" = "sha256-lCRFwyRbInMP1Bpnp8XCMdEcsbmTa5wPdjNPt9C0Row=";
      };
    }
    {
      def = defs."4.0.1";
      releases."4.0.1" = "sha256-ltM6u0uwBwx74P7UJGzThBYYgyX4IEaCFEcZOFRbGsg=";
    }
  ];
  packageArgs = {
    infra = {
      inherit (pkgs) lib fetchurl;
    };
    inherit pname versionTable;
    packageMeta.upstream = {
      type = "directory-index";
      url = "https://www.bytereef.org/mpdecimal/download.html";
      pattern = "mpdecimal-[0-9][^\"]*\\.tar\\.gz";
      normalise =
        file:
        if pkgs.lib.hasPrefix "mpdecimal-" file && pkgs.lib.hasSuffix ".tar.gz" file then
          pkgs.lib.removeSuffix ".tar.gz" (pkgs.lib.removePrefix "mpdecimal-" file)
        else
          null;
      include = version: builtins.match "[0-9]+(\\.[0-9]+)*" version != null;
    };
    extraArgs.mkTests =
      package:
      import ./tests {
        inherit tvpLib package;
        pkgs = tvpLib.tests.withBase {
          inherit pkgs;
          base.stdenv = package.stdenv;
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
    "4.0.1" = {
      constructor = tvp.builder;
      builder = ./native/build-4.0.1.nix;
      base = candidate.base;
      source =
        { version, sha256 }:
        import <nix/fetchurl.nix> {
          url = "https://www.bytereef.org/software/mpdecimal/releases/mpdecimal-${version}.tar.gz";
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
      "4.0.0" = versionTable."4.0.0" // {
        def = if native then ordinaryDefs."4.0.0" else versionTable."4.0.0".def;
      };

      "4.0.1" = versionTable."4.0.1" // {
        def = if native then ownedDefs."4.0.1" else versionTable."4.0.1".def;
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
          inherit package;
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
  aliases = tvpLib.packages.mkAliases { inherit pname versionTable canonical; };
}

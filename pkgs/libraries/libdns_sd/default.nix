{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  defs = tvpLib.packages.mkDefs {
    "2881.120.11" = {
      builder = ./build-2881.120.11.nix;
      base = tvp.bases.default;
      deps.patchelf = tvp.packages.patchelf;
    };
  };
  pname = "libdns_sd";
  versionTable = tvpLib.packages.mkTable [
    {
      def = defs."2881.120.11";
      releases."2881.120.11" = "sha256-9mXPArXJMPm3D7ObdWfwPdghmXWUxWzjmQmOqgNy+xU=";
    }
  ];
  packageArgs = {
    infra = {
      inherit (pkgs) lib fetchurl;
    };
    inherit pname versionTable;
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
  # Ordinary native release only. Frozen construction retains the complete call.
  constructionRecipe = packageArgs;
  candidate = import ../../../bases/source-gnu { };
  native = pkgs.stdenv.hostPlatform.system == "x86_64-linux";
  constructionTool =
    name:
    tvpLib.packages.withConstraint {
      category = "construction";
      reason = "Retained source-GNU ${name} is an explicit build host tool, independent of this ordinary library target.";
    } candidate.tools.${name};
  ownedDefs = tvpLib.packages.mkDefs {
    "2881.120.11" = {
      constructor = tvp.builder;
      builder = ./native/build-2881.120.11.nix;
      base = candidate.base;
      source =
        { version, sha256 }:
        import <nix/fetchurl.nix> {
          url = "https://github.com/apple-oss-distributions/mDNSResponder/archive/refs/tags/mDNSResponder-${version}.tar.gz";
          inherit sha256;
        };
      helpers = { inherit tvp; };
      testContext =
        package:
        tvpLib.tests.fromPackage {
          builder = tvp.builder;
          inherit package;
        };
      deps = {
        bash = constructionTool "bash";
        coreutils = constructionTool "coreutils";
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
  publicArgs = packageArgs // {
    versionTable = versionTable // {
      "2881.120.11" = versionTable."2881.120.11" // {
        def = if native then ownedDefs."2881.120.11" else versionTable."2881.120.11".def;
      };
    };
    extraArgs.mkTests = pkgs.lib.makeOverridable (
      { pkgs }:
      package:
      if package ? testContext then
        import ./tests/native.nix { inherit package; }
      else
        (
          package:
          import ./tests {
            inherit tvpLib package;
            pkgs = tvpLib.tests.withBase {
              inherit pkgs;
              base.stdenv = package.stdenv;
            };
          }
        )
          package
    ) { inherit pkgs; };
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

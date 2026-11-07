{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  defs = tvpLib.packages.mkDefs {
    "10.44" = {
      builder = ./build-10.44.nix;
      base = tvp.bases.default;
      deps = {

      };
    };
  };
  versionTable = tvpLib.packages.mkTable [
    {
      def = defs."10.44";
      releases = {
        "10.44" = "sha256-008C4RPPcZOh6/J3DTrFJwiNSF1OBH7RDl0hfG713pY=";
        "10.47" = "sha256-R/6MmUYSUNQviebo/a66naBXhV0G63/AjZygP9CNe8c=";
        "10.48" = "sha256-tsaP3286wxOItQqon/D8ScAMmHwW57UUZJHRIAPyyO0=";
        "10.49" = "sha256-U8FW4bpBaiDajmU5XaoTLaDYDnaRBCTKyj/Nrngx04Q=";
      };
    }
  ];
  pname = "pcre2";
  packageArgs = {
    infra = {
      inherit (pkgs) lib fetchurl;
    };
    inherit pname versionTable;
    extraArgs.mkTests = package: import ./tests { inherit pkgs tvpLib package; };
    packageMeta.upstream = import ./upstream.nix;
  };
  # Complete legacy call: table, factories, source construction and test routing.
  constructionRecipe = packageArgs;
  candidate = import ../../../bases/source-gnu { };
  native = pkgs.stdenv.hostPlatform.system == "x86_64-linux";
  constructionTool =
    name:
    tvpLib.packages.withConstraint {
      category = "construction";
      reason = "Retained source-GNU ${name} is an explicit build-only host generation, independent of these target libraries and commands.";
    } candidate.tools.${name};
  ownedDefs = tvpLib.packages.mkDefs {
    "10.49" = {
      constructor = tvp.builder;
      builder = ./native/build-10.49.nix;
      base = candidate.base;
      source =
        { version, sha256 }:
        import <nix/fetchurl.nix> {
          url = "https://github.com/PCRE2Project/pcre2/releases/download/pcre2-${version}/pcre2-${version}.tar.bz2";
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
        bzip2 = constructionTool "bzip2";
        perl = constructionTool "perl";
      };
    };
  };
  publicArgs = packageArgs // {
    versionTable = versionTable // {
      "10.49" = versionTable."10.49" // {
        def = if native then ownedDefs."10.49" else versionTable."10.49".def;
      };
    };
    extraArgs.mkTests =
      package:
      if package ? testContext then
        import ./tests/native-default.nix { inherit pkgs tvpLib package; }
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
  aliases = tvpLib.packages.mkAliases { inherit pname versionTable canonical; };
}

{ pkgs, tvp }:
let
  previous = import ./legacy.nix { inherit pkgs tvp; };
  retainedBase = import ../../../bases/tiers/construction.nix {
    inherit (pkgs) lib;
    builder = tvp.builder;
  } tvp.bases.default;
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build-1.17.3.nix;
        base = retainedBase;
        deps.ruby = tvp.packages.ruby_2;
      };
      releases = {
        "1.17.3" = "sha256-vEv3W1SLJ0UaqfRDsYxGpzndIq1596X5C0hTdqZ9w1I=";
        "2.1.2" = "sha256-o9icmn+/6TZFEsrBC8jcT5w3DkE3XAPNNsrTHu9vuWE=";
      };
    }
    {
      def = {
        builder = ./build-1.17.3.nix;
        base = retainedBase;
        deps.ruby = tvp.packages.ruby_3.override {
          rustc = tvp.lib.packages.withConstraint {
            category = "construction";
            reason = "Retained complete Rust seed generation; historical construction and tests must not follow the promoted public provider.";
          } (import ../../compilers/rust/legacy.nix { inherit pkgs tvp; }).canonical.rustc_1_97_1;
        };
      };
      releases."2.5.11" = "sha256-3XhL/lODSzmlbmQtvG4eyhmi5kVOTVOZTLcpgAWsTC4=";
    }
    {
      def = {
        builder = ./build-1.17.3.nix;
        deps.ruby = tvp.packages.ruby_3;
        opts.offlineControls = true;
      };
      releases."2.5.20" = "sha256-g7zLXMxFbjRwiaoFMY7NJ7uYQMqmTtFsFwO1DUmwq5Q=";
    }
  ];
  pname = "bundler";
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable;
    inherit (previous.recipes.bundler) packageMeta;
    source =
      { version, sha256 }:
      import <nix/fetchurl.nix> {
        url = "https://rubygems.org/gems/bundler-${version}.gem";
        inherit sha256;
      };
    tests = import ./tests;
    testDeps = {
      ruby = tvp.packages.ruby_3;
      libyaml = tvp.packages.libyaml;
      alternateYaml = tvp.packages.libyaml_0_2_4;
      sourceCompiler = tvp.baseTiers.full.compiler;
    };
  };
  canonical = tvp.lib.packages.mkVersions family;
  constructionRecipe =
    (import ./legacy.nix {
      inherit pkgs;
      tvp = tvp // {
        packages =
          tvp.packages // (import ../../runtimes/ruby/retained-public.nix { inherit pkgs tvp; }).aliases;
      };
    }).recipes.bundler;
in
{
  recipes.bundler = family // {
    inherit constructionRecipe;
  };
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}

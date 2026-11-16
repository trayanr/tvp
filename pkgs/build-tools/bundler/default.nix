{ pkgs, tvp }:
let
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build-1.17.3.nix;
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
        deps.ruby = tvp.packages.ruby_3;
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
    packageMeta = {
      upstream = {
        type = "rubygems";
        url = "https://rubygems.org/api/v1/versions/bundler.json";

        include =
          version:
          !(
            pkgs.lib.hasInfix "pre" version
            || pkgs.lib.hasInfix "rc" version
            || pkgs.lib.hasInfix "beta" version
          );
      };
    };
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
      alternateYaml = tvp.lib.packages.withConstraint {
        reason = "Older LibYAML provider for the runtime rebinding control; deliberately distinct from the default library.";
      } tvp.packages.libyaml_0_2_4;
      sourceCompiler = tvp.bases.gcc_16.full.compiler;
    };
  };
  canonical = tvp.lib.packages.mkVersions family;

in
{
  recipes.bundler = family;
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}

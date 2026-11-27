{ tvp, ... }:
let
  pname = "npm";
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build.nix;
        deps.nodejs = tvp.lib.packages.withConstraint {
          reason = "Run npm 9.5.1 with the exact TVP Node.js 18.14.2 runtime selected for this release.";
        } tvp.packages.nodejs_18_14_2;
      };
      releases."9.5.1" = "sha256-9fDL8NBU5gS/lJe5TwlfiScC6SWTYaZXewoP1JdVz78=";
    }
  ];
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable;
    source = tvp.lib.sources.archive {
      url = version: "https://registry.npmjs.org/npm/-/npm-${version}.tgz";
      discovery = {
        type = "json-index";
        url = "https://registry.npmjs.org/npm";
        selector = ".versions | keys[]";
        include = version: builtins.match "9\\.[0-9]+\\.[0-9]+" version != null;
        scope = "stable npm 9 releases";
      };
    };
    tests = import ./tests;
  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes.npm = family;
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}

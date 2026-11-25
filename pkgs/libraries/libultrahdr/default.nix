{ pkgs, tvp }:
let
  pname = "libultrahdr";
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build.nix;
        deps.jpeg = tvp.packages.libjpeg-turbo;
      };
      releases."2.0.2" = "sha256-qo0ZO7iHw0jEGXgFEd0Ds3T04Hr4gSttP4DIU3zx7yw=";
    }
  ];
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable;
    source = tvp.lib.sources.archive {
      url = version: "https://codeload.github.com/google/libultrahdr/tar.gz/refs/tags/v${version}";
      discovery = {
        type = "git-tags";
        url = "https://github.com/google/libultrahdr";
        prefix = "v";
        include = version: builtins.match "[0-9]+\\.[0-9]+\\.[0-9]+" version != null;
      };
    };
    tests = import ./tests.nix;
  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes.libultrahdr = family;
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}

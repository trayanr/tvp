{ tvp, ... }:
let
  pname = "nixfmt";
  project = "https://github.com/NixOS/nixfmt";
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build.nix;
        blob = {
          reason = "Use the official static Linux release for TVP's formatter.";
          needs = "A TVP GHC bootstrap, Cabal and pinned Haskell dependencies to build nixfmt from source.";
          blocked.package = "nixfmt-from-source";
        };
      };
      releases."1.5.0" = "sha256-qgKSR6uJyJfi85SEY5Z1U/kC+G6G40AvooyynEpE90U=";
    }
  ];
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable;
    source = tvp.lib.sources.archive {
      url = version: "${project}/releases/download/v${version}/nixfmt";
      discovery = {
        type = "json-index";
        url = "https://api.github.com/repos/NixOS/nixfmt/releases?per_page=100";
        selector = ''
          .[] | select(any(.assets[]; .name == "nixfmt")) | .tag_name | ltrimstr("v")
        '';
        include = version: builtins.compareVersions version "1.2.0" >= 0;
      };
    };
    tests = import ./tests.nix;
  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes.${pname} = family;
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}

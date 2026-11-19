{ tvp, ... }:
let
  pname = "keyutils";
  repository = "https://git.kernel.org/pub/scm/linux/kernel/git/dhowells/keyutils.git";
  versionTable = tvp.lib.packages.mkTable [
    {
      def.builder = ./build.nix;
      releases."1.6.3" = "sha256-ph1XBhNq5MBb1I+GGGvP29iN2L1RB+Phlckkz8Gzm7Q=";
    }
  ];
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable;
    source = tvp.lib.sources.archive {
      url = version: "${repository}/snapshot/keyutils-${version}.tar.gz";
      discovery = {
        type = "git-tags";
        url = repository;
        prefix = "v";
        include = version: builtins.match "[0-9]+([.][0-9]+)+" version != null;
      };
    };
    tests = import ./tests;
  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes.${pname} = family;
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}

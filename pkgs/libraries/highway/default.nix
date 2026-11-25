{ tvp, ... }:
let
  pname = "highway";
  versionTable = tvp.lib.packages.mkTable [
    {
      def.builder = ./build.nix;
      releases."1.4.0" = "sha256-NvZyq0jds8hVXp6J4W/kAM19FsbrRVoaPQwUamOrq9w=";
    }
  ];
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable;
    source = tvp.lib.sources.archive {
      url = version: "https://github.com/google/highway/releases/download/${version}/highway-${version}.tar.gz";
      discovery = {
        type = "git-tags";
        url = "https://github.com/google/highway.git";
        include = version: builtins.match "[0-9]+[.][0-9]+[.][0-9]+" version != null;
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

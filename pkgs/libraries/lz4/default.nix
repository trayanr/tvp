{ pkgs, tvp }:
let
  pname = "lz4";
  versionTable = tvp.lib.packages.mkTable [
    {
      def.builder = ./build.nix;
      releases."1.11.1" = "sha256-aD/tCKhErQEhljgeQLrfgMC75JYpWXYUFtQcnmfXfsc=";
    }
  ];
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable;
    source = tvp.lib.sources.archive {
      url = version: "https://github.com/lz4/lz4/releases/download/v${version}/lz4-${version}.tar.gz";
      discovery = {
        type = "git-tags";
        url = "https://github.com/lz4/lz4";
        normalise =
          tag:
          if builtins.match "v[0-9]+\\.[0-9]+\\.[0-9]+" tag == null then
            null
          else
            pkgs.lib.removePrefix "v" tag;
      };
    };
    tests = import ./tests.nix;
  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes.lz4 = family;
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}

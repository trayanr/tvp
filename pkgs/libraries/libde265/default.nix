{ tvp, ... }:
let
  pname = "libde265";
  versionTable = tvp.lib.packages.mkTable [
    {
      def.builder = ./build.nix;
      releases."1.1.3" = "sha256-VUIovRd4jJmn5js3q1Y0ciGQ5uK/YMHcsBzvMo4TOQU=";
    }
  ];
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable;
    source = tvp.lib.sources.archive {
      url =
        version:
        "https://github.com/strukturag/libde265/releases/download/v${version}/libde265-${version}.tar.gz";
      discovery = {
        type = "git-tags";
        url = "https://github.com/strukturag/libde265";
        prefix = "v";
        include = version: builtins.match "[0-9]+\\.[0-9]+\\.[0-9]+" version != null;
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

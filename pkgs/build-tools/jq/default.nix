{ tvp, ... }:
let
  pname = "jq";
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build.nix;
        deps.oniguruma = tvp.packages.oniguruma_6_9;
      };
      releases."1.8.2" = "sha256-cbjW6PX+gfbG0NEQ44kiUfbOdu0JWr0xXibm4Rk6868=";
    }
  ];
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable;
    source = tvp.lib.sources.archive {
      url = version: "https://github.com/jqlang/jq/releases/download/jq-${version}/jq-${version}.tar.gz";
      discovery = {
        type = "git-tags";
        url = "https://github.com/jqlang/jq.git";
        prefix = "jq-";
        include = version: builtins.match "[0-9]+([.][0-9]+)+" version != null;
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

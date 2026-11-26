{ pkgs, tvp }:
let
  pname = "libuuid";
  versionTable = tvp.lib.packages.mkTable [
    {
      def.builder = ./build.nix;
      releases."2.42.4" = "sha256-+9YqEAq3u4dGugZhJVw8SBhbHpAhUHxiTaAfvGljMOw=";
    }
  ];
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable;
    source = tvp.lib.sources.archive {
      url =
        version:
        "https://www.kernel.org/pub/linux/utils/util-linux/v${pkgs.lib.versions.majorMinor version}/util-linux-${version}.tar.xz";
      discovery = {
        type = "git-tags";
        url = "https://github.com/util-linux/util-linux";
        normalise =
          tag:
          if builtins.match "v[0-9]+\\.[0-9]+(\\.[0-9]+)?" tag == null then
            null
          else
            builtins.substring 1 (builtins.stringLength tag) tag;
      };
    };
    tests = import ./tests.nix;
  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes.libuuid = family;
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}

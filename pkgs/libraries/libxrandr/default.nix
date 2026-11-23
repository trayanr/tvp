{ tvp, ... }:
let
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build.nix;
        deps = {
          pkgConfig = tvp.packages.pkg-config;
          libx11 = tvp.packages.libx11_1;
          libxext = tvp.packages.libxext_1;
          libxrender = tvp.packages.libxrender;
          xorgproto = tvp.packages.xorgproto;
          xtrans = tvp.packages.xtrans_1;
          libxcb = tvp.packages.libxcb_1;
          libxau = tvp.packages.libxau_1;
          libxdmcp = tvp.packages.libxdmcp_1;
        };
      };
      releases = {
        "1.5.3" = "sha256-iXY5AUp44Ul3BNZpxd1WgtchkxpEUsiae6YmdgZOtCg=";
        "1.5.4" = "sha256-GtWwZTdfSoWRWqYGEcxkB8BgSSohTX+dryFL51LDtNM=";
        "1.5.5" = "sha256-crkiwudlQ06enwlgFIBwvUUEsogmPihopMzOG3zydno=";
      };
    }
  ];
  pname = "libxrandr";
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable;
    source = tvp.lib.sources.directory {
      url = "https://www.x.org/releases/individual/lib/";
      archive = "libXrandr-{version}.tar.xz";
    };
    tests = import ./tests/owned.nix;

  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes.libxrandr = family;
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}

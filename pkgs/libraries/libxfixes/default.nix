{ tvp, ... }:
let
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build.nix;
        deps = {
          pkgConfig = tvp.packages.pkg-config;
          libx11 = tvp.packages.libx11_1;
          xorgproto = tvp.packages.xorgproto;
          xtrans = tvp.packages.xtrans_1;
          libxcb = tvp.packages.libxcb_1;
          libxau = tvp.packages.libxau_1;
          libxdmcp = tvp.packages.libxdmcp_1;
        };
      };
      releases = {
        "6.0.1" = "sha256-tpX5PNJJlCGrAtInREWOZQzMiMHUyBMNYCACE6vALVg=";
        "6.0.2" = "sha256-OfEV1y2cX4ER5GhBZNPWjMH9Ifmyf/JAGwj938D0Cbo=";
      };
    }
  ];
  pname = "libxfixes";
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable;
    source = tvp.lib.sources.directory {
      url = "https://www.x.org/releases/individual/lib/";
      archive = "libXfixes-{version}.tar.xz";
    };
    tests = import ./tests/owned.nix;

  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes.libxfixes = family;
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}

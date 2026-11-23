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
        "1.3.5" = "sha256-2xTAyJXFfqM6hVnejLK5PcdsQupKOeKU0XWTihM9e8o=";
        "1.3.6" = "sha256-7bWfojmU5AX9xbQAr99YIK5hYLlPNePcPaRFehbol1M=";
        "1.3.7" = "sha256-bGQ8cDXNrPZ6/WjyXQG5DviJ1UbJ/NfArffCz5Hjoy0=";
      };
    }
  ];
  pname = "libxext";
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable;
    source = tvp.lib.sources.directory {
      url = "https://www.x.org/releases/individual/lib/";
      archive = "libXext-{version}.tar.xz";
    };
    tests = import ./tests/owned.nix;

  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes.libxext = family;
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}

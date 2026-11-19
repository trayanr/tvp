{ tvp, ... }:
let
  pname = "tzdata";
  versionTable = tvp.lib.packages.mkTable [
    {
      def.builder = ./build.nix;
      releases."2026f" = "sha256-NXgp46FqeCJNI/GuIydwTB2h/TX2dpp6rAaCdV+5Ano=";
    }
  ];
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable;
    source = tvp.lib.sources.directory {
      url = "https://data.iana.org/time-zones/releases/";
      archive = "tzdb-{version}.tar.lz";
      discovery.include = version: builtins.match "[0-9]{4}[a-z]+" version != null;
    };
    tests = import ./tests.nix;
  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes.tzdata = family;
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}

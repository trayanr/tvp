{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  platform = tvpLib.platforms.forStdenv tvp.bases.default.stdenv;
  defs = tvpLib.packages.mkDefs {
    "20171003" = {
      builder = ./build-20171003.nix;
      base = tvp.bases.default;
      deps.bash = tvp.packages.bash_5_2_37;
      opts = {
        inherit (platform) goOS goArch;
        # This dated upstream repack retains the older VERSION file.
        reportedVersion = "go1.4-bootstrap-20170531";
      };
    };
  };
  pname = "go-bootstrap";
  versionTable = tvpLib.packages.mkTable [
    {
      def = defs."20171003";
      releases."20171003" = "sha256-9P9bXrOjyuHJk3I/PqtRnFuuGIZrXl+W/hEC8MtcPlI=";
    }
  ];
  canonical = tvpLib.packages.mkVersions {
    infra = {
      inherit (pkgs) lib fetchurl;
    };
    inherit pname versionTable;
    extraArgs.mkTests =
      package:
      import ./tests {
        inherit tvpLib package;
        pkgs = tvpLib.tests.withBase {
          inherit pkgs;
          base.stdenv = package.stdenv;
        };
      };
  };
in
{
  inherit canonical;
  aliases = tvpLib.packages.mkAliases { inherit pname versionTable canonical; };
}

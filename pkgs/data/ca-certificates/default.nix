{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  defs = tvpLib.packages.mkDefs {
    "2026-10-20" = {
      builder = ./build-2026-10-20.nix;
      base = tvp.bases.default;
      deps = { };
    };
  };
  pname = "ca-certificates";
  versionTable = tvpLib.packages.mkTable [
    {
      def = defs."2026-10-20";
      releases."2026-10-20" = "sha256-eW8Tib/qE8DtePZjt2W6r/VKUI5Ug3hr1uznPF4+PL4=";
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
        openssl = tvp.packages.openssl_3_6_3;
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

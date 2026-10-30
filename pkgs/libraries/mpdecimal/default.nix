{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  defs = tvpLib.packages.mkDefs {
    "4.0.0" = {
      builder = ./build-4.0.0.nix;
      base = tvp.bases.default;
      deps = { };
      # 4.0.0 inherits LD=ld but uses compiler-driver flags for shared links.
      opts.linkWithCC = true;
    };
    "4.0.1" = {
      builder = ./build-4.0.0.nix;
      base = tvp.bases.default;
      deps = { };
    };
  };
  pname = "mpdecimal";
  versionTable = tvpLib.packages.mkTable [
    {
      def = defs."4.0.0";
      releases = {
        "4.0.0" = "sha256-lCRFwyRbInMP1Bpnp8XCMdEcsbmTa5wPdjNPt9C0Row=";
      };
    }
    {
      def = defs."4.0.1";
      releases."4.0.1" = "sha256-ltM6u0uwBwx74P7UJGzThBYYgyX4IEaCFEcZOFRbGsg=";
    }
  ];
  canonical = tvpLib.packages.mkVersions {
    infra = {
      inherit (pkgs) lib fetchurl;
    };
    inherit pname versionTable;
    packageMeta.upstream = {
      type = "directory-index";
      url = "https://www.bytereef.org/mpdecimal/download.html";
      pattern = "mpdecimal-[0-9][^\"]*\\.tar\\.gz";
      normalise =
        file:
        if pkgs.lib.hasPrefix "mpdecimal-" file && pkgs.lib.hasSuffix ".tar.gz" file then
          pkgs.lib.removeSuffix ".tar.gz" (pkgs.lib.removePrefix "mpdecimal-" file)
        else
          null;
      include = version: builtins.match "[0-9]+(\\.[0-9]+)*" version != null;
    };
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

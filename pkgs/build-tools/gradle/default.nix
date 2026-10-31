{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  defs = tvpLib.packages.mkDefs {
    "9.3.1" = {
      builder = ./build-9.3.1.nix;
      base = tvp.bases.default;
      deps = {
        jdk = tvp.packages.jdk_21;
        python = tvp.packages.python_3;
        bash = tvp.packages.bash_5;
        unzip = tvp.packages.unzip;
        coreutils = tvp.packages.coreutils;
      };
      blob = {
        reason = "Pinned upstream Gradle distribution with its bundled Java bytecode and native service libraries.";
        needs = "Source Gradle bootstrap and a locked source dependency repository.";
        blocked.package = "gradle-from-source";
      };
    };
  };
  pname = "gradle";
  versionTable = tvpLib.packages.mkTable [
    {
      def = defs."9.3.1";
      releases."9.3.1" = "sha256-F/J3hn9pFNYbGqAu+rG6e7Q5rWUspIXNjKaEL8zsbkM=";
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

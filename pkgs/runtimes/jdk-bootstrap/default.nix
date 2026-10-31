{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  platform = tvpLib.platforms.forStdenv tvp.bases.default.stdenv;
  defs = tvpLib.packages.mkDefs {
    "21.0.13" = {
      builder = ./build-21.0.13.nix;
      base = tvp.bases.default;
      deps = {
        patchelf = tvp.packages.patchelf;
        zlib = tvp.packages.zlib_1;
        alsa = tvp.packages.alsa-lib_1;
        fontconfig = tvp.packages.fontconfig_2;
      };
      opts = {
        inherit (platform) dynamicLinker;
        buildNumber = "9";
      };
      blob = {
        reason = "Explicit Temurin binary boot JDK for compiling the first owned OpenJDK source release.";
        needs = "A source Java bootstrap chain from a non-Java compiler seed.";
        blocked.package = "jdk-bootstrap-from-source";
      };
    };
  };
  pname = "jdk-bootstrap";
  versionTable = tvpLib.packages.mkTable [
    {
      def = defs."21.0.13";
      releases."21.0.13" = "sha256-1/XVz4ZaKQK3D/VJuXWGp9PyNOAW8EGrRH6nQMfWbRw=";
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

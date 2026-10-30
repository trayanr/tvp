{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  defs = tvpLib.packages.mkDefs {
    "3.1" = {
      builder = ./build-3.1.nix;
      base = tvp.bases.default;
      deps = {
        patchelf = tvp.packages.patchelf_0_19_2;
      };
    };
  };
  pname = "gperf";
  versionTable = tvpLib.packages.mkTable [
    {
      def = defs."3.1";
      releases."3.1" = "sha256-WIVGuUW7pLcLajphboC0q0ZuPzMCSjUvwhmBEs27OuI=";
      releases."3.2" = "sha256-4N2t67OWkGo+PkysL2l8jWq5Lf+l02WlvCPH1B0w72I=";
      releases."3.2.1" = "sha256-7VrTF4WOCputu62nDfQBlAAuFuiDSsJEkTB8iPlvlwI=";
      releases."3.3" = "sha256-/Yfgq6fkOuBUg3r9bNTbA6PyaT3rNhkIXm7Z2NlgStg=";
    }
  ];
  canonical = tvpLib.packages.mkVersions {
    infra = {
      inherit (pkgs) lib fetchurl;
    };
    inherit pname versionTable;
    packageMeta.upstream = {
      type = "directory-index";
      url = "https://mirrors.kernel.org/gnu/gperf/";
      pattern = "gperf-[0-9]+(\\.[0-9]+)*\\.tar\\.(gz|bz2|xz|lz)";
      normalise =
        file:
        let
          matched = builtins.match "gperf-([0-9]+(\\.[0-9]+)*)\\.tar\\.(gz|bz2|xz|lz)" file;
        in
        if matched == null then null else builtins.head matched;
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

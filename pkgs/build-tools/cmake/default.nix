{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  defs = tvpLib.packages.mkDefs {
    "4.4.5" = {
      builder = ./build-4.4.5.nix;
      base = tvp.bases.default;
      deps = {
        bash = tvp.packages.bash_5;
        openssl = tvp.packages.openssl_4;
        zlib = tvp.packages.zlib_1;
        bzip2 = tvp.packages.bzip2_1;
        xz = tvp.packages.xz_5;
        zstd = tvp.packages.zstd_1;
        pkg-config = tvp.packages.pkg-config;
      };
      patches = [
        {
          file = ./patches/store-shell.patch;
          reason = "Store-layout adaptation: use the declared Bash instead of /bin/sh, which is absent in Nix build sandboxes.";
        }
      ];
    };
  };
  versionTable = tvpLib.packages.mkTable [
    {
      def = defs."4.4.5";
      releases."4.4.5" = "sha256-oMVMiKu4B43Y7MrbcX/GuxlL8Y59RMhjCZECiIhuBOI=";
    }
  ];
  pname = "cmake";
  testDeps = {
    ninja = tvp.packages.ninja;
  };
  canonical = tvpLib.packages.mkVersions {
    inherit testDeps;
    infra = {
      inherit (pkgs) lib fetchurl;
    };
    inherit pname versionTable;
    extraArgs.mkTests = pkgs.lib.makeOverridable (
      { pkgs }:
      package:
      import ./tests {
        inherit tvpLib package;
        ninja = testDeps.ninja;
        pkgs = tvpLib.tests.withBase {
          inherit pkgs;
          base.stdenv = package.stdenv;
        };
      }
    ) { inherit pkgs; };
    packageMeta.upstream = {
      type = "git-tags";
      url = "https://github.com/Kitware/CMake.git";
      normalise = tag: pkgs.lib.removePrefix "v" tag;
      include = version: builtins.match "[0-9]+(\\.[0-9]+)*" version != null;
    };
  };
in
{
  inherit canonical;
  aliases = tvpLib.packages.mkAliases { inherit pname versionTable canonical; };
}

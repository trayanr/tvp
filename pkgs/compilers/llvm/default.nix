{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  platform = tvpLib.platforms.forStdenv tvp.bases.default.stdenv;
  defs = tvpLib.packages.mkDefs {
    "23.1.4" = {
      builder = ./build-23.1.4.nix;
      base = tvp.bases.default;
      deps = {
        bash = tvp.packages.bash_5;
        python = tvp.packages.python-build_3;
        cmake = tvp.packages.cmake;
        ninja = tvp.packages.ninja;
        pkg-config = tvp.packages.pkg-config;
        patchelf = tvp.packages.patchelf;
        zlib = tvp.packages.zlib_1;
        zstd = tvp.packages.zstd_1;
        libffi = tvp.packages.libffi_3;
        libxml2 = tvp.packages.libxml2_2;
      };
      opts = {
        inherit (platform) dynamicLinker;
      };
    };
  };
  pname = "llvm";
  versionTable = tvpLib.packages.mkTable [
    {
      def = defs."23.1.4";
      releases."23.1.4" = "sha256-gZ7Pc1Hxpm92stcB2JQvqvX66zJMuQydWwkN4UJDS7I=";
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
  aliases = tvpLib.packages.mkAliases { inherit pname versionTable canonical; } // {
    clang = canonical.llvm_23_1_4;
    clang_23_1_4 = canonical.llvm_23_1_4;
    lld = canonical.llvm_23_1_4;
    lld_23_1_4 = canonical.llvm_23_1_4;
  };
}

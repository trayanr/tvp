{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  platform = tvpLib.platforms.forStdenv tvp.bases.default.stdenv;
  defs = tvpLib.packages.mkDefs {
    "23.1.4" = {
      builder = ./build-23.1.4.nix;
      base = tvp.bases.default;
      deps = {
        bash = tvp.packages.bash_5_2_37;
        python = tvp.packages.python-build_3_12_5;
        cmake = tvp.packages.cmake_4_4_5;
        ninja = tvp.packages.ninja_1_13_2;
        pkg-config = tvp.packages.pkg-config_0_29_2;
        patchelf = tvp.packages.patchelf_0_19_2;
        zlib = tvp.packages.zlib_1_3_2;
        zstd = tvp.packages.zstd_1_5_6;
        libffi = tvp.packages.libffi_3_8_0;
        libxml2 = tvp.packages.libxml2_2_15_3;
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

{ tvp, ... }:
let
  pname = "llvm";
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build-owned-23.1.4.nix;
        deps = {
          zlib = tvp.packages.zlib_1;
          zstd = tvp.packages.zstd_1;
          libffi = tvp.packages.libffi_3;
          libxml2 = tvp.packages.libxml2_2;
          # These are installed target interfaces, not the construction compiler.
          rawGCC = tvp.packages.gcc_16;
          cxxRuntime = tvp.packages.gcc_16;
          gccRuntime = tvp.packages.gcc_16;
          libc = tvp.packages.glibc_2;
          targetBinutils = tvp.packages.binutils_2;
        };
      };
      releases."23.1.4" = "sha256-gZ7Pc1Hxpm92stcB2JQvqvX66zJMuQydWwkN4UJDS7I=";
    }
  ];
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable;
    source =
      { version, sha256 }:
      import <nix/fetchurl.nix> {
        url = "https://github.com/llvm/llvm-project/releases/download/llvmorg-${version}/llvm-project-${version}.src.tar.xz";
        inherit sha256;
      };
    tests = import ./tests/installed.nix;
  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes.llvm = family;
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; } // {
    clang = canonical.llvm_23_1_4;
    clang_23_1_4 = canonical.llvm_23_1_4;
    lld = canonical.llvm_23_1_4;
    lld_23_1_4 = canonical.llvm_23_1_4;
  };
}

{ pkgs, tvp }:
let
  retained = (import ./legacy.nix { inherit pkgs tvp; }).publicArgs;
  # Preserve the actual configure-visible tool generations while the compiler
  # remains the closed earlier full-tier driver, never the selected target GCC.
  compilerHostBase = tvp.baseTiers.full.override {
    shell = tvp.packages.bash_5;
    standardTools = {
      cmake = tvp.packages.cmake;
      ninja = tvp.packages.ninja;
      pkg-config = tvp.packages.pkg-config;
      sed = tvp.packages.gnused;
      grep = tvp.packages.gnugrep;
      diffutils = tvp.packages.diffutils;
    };
  };
  pname = "llvm";
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build-owned-23.1.4.nix;
        base = compilerHostBase;
        deps = {
          python = tvp.packages.python-build_3;
          perl = tvp.packages.perl_5;
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
        opts.dynamicLinker = "lib/ld-linux-x86-64.so.2";
      };
      releases."23.1.4" = "sha256-gZ7Pc1Hxpm92stcB2JQvqvX66zJMuQydWwkN4UJDS7I=";
    }
  ];
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable;
    packageMeta = retained.packageMeta or { };
    source =
      { version, sha256 }:
      pkgs.fetchurl {
        url = "https://github.com/llvm/llvm-project/releases/download/llvmorg-${version}/llvm-project-${version}.src.tar.xz";
        inherit sha256;
      };
    tests = import ./tests/installed.nix;
  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes.llvm = family // {
    constructionRecipe = retained;
  };
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; } // {
    clang = canonical.llvm_23_1_4;
    clang_23_1_4 = canonical.llvm_23_1_4;
    lld = canonical.llvm_23_1_4;
    lld_23_1_4 = canonical.llvm_23_1_4;
  };
}

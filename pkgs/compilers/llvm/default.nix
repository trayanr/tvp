{ tvp, ... }:
let
  pname = "llvm";
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build-11.1.0.nix;
        # Older sources assume transitive standard-library includes that fail
        # on GCC 13 and newer. Use the retained source-owned construction base.
        base = tvp.bases.gcc_9.full;
        deps = {
          # The historical installed scripts use imp and distutils.
          python = tvp.packages.python_3_11;
          zlib = tvp.packages.zlib_1;
          libffi = tvp.packages.libffi_3;
          libxml2 = tvp.lib.packages.withConstraint {
            reason = "The standard ICU provider requires newer libstdc++ symbols than the GCC 9 host runtime provides.";
          } (tvp.packages.libxml2_2.override { icu = null; });
          rawGCC = tvp.packages.gcc_13;
          cxxRuntime = tvp.packages.gcc_13;
          gccRuntime = tvp.packages.gcc_13;
          libc = tvp.packages.glibc_2;
          targetBinutils = tvp.packages.binutils_2;
        };
      };
      releases = {
        "11.1.0" = "sha256-dNJSkVn9EYw+rG+QEHtWEbzMb2R/3qEEAkGD6NXiWDE=";
        "14.0.6" = "sha256-izz9e8aVvWzqDzf1PwmB80+HSW554lKYdP0DovndOoo=";
      };
    }
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
    source = tvp.lib.sources.archive {
      url =
        version:
        "https://github.com/llvm/llvm-project/releases/download/llvmorg-${version}/llvm-project-${version}.src.tar.xz";
      discovery = {
        type = "git-tags";
        url = "https://github.com/llvm/llvm-project";
        prefix = "llvmorg-";
        include = version: builtins.match "[0-9]+(\\.[0-9]+)+" version != null;
      };
    };
    tests =
      args:
      (import ./tests/installed.nix args)
      // (
        if (args.package.specification.installedInterface.orcV1 or null) != null then
          import ./tests/jit.nix args
        else
          { }
      );
  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes.llvm = family;
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; } // {
    clang = canonical.llvm_23_1_4;
    clang_11 = canonical.llvm_11_1_0;
    clang_11_1_0 = canonical.llvm_11_1_0;
    clang_14 = canonical.llvm_14_0_6;
    clang_14_0_6 = canonical.llvm_14_0_6;
    clang_23_1_4 = canonical.llvm_23_1_4;
    lld = canonical.llvm_23_1_4;
    lld_11 = canonical.llvm_11_1_0;
    lld_11_1_0 = canonical.llvm_11_1_0;
    lld_14 = canonical.llvm_14_0_6;
    lld_14_0_6 = canonical.llvm_14_0_6;
    lld_23_1_4 = canonical.llvm_23_1_4;
  };
}

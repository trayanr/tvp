{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  previous = import ./legacy.nix { inherit pkgs tvp; };
  constructionRecipe = previous.publicArgs;
  candidate = import ../../../bases/source-gnu { };
  constructionTool =
    name:
    tvpLib.packages.withConstraint {
      category = "construction";
      reason = "Retained source-GNU ${name} host tool; independent of the ordinary compiler payload.";
    } candidate.tools.${name};
  defs = tvpLib.packages.mkDefs {
    "23.1.4" = {
      constructor = tvp.builder;
      builder = ./native/build-23.1.4.nix;
      base = candidate.base;
      helpers = {
        inherit tvp;
      };
      source =
        { version, sha256 }:
        pkgs.fetchurl {
          url = "https://github.com/llvm/llvm-project/releases/download/llvmorg-${version}/llvm-project-${version}.src.tar.xz";
          inherit sha256;
        };
      testContext =
        package:
        tvpLib.tests.fromPackage {
          builder = tvp.builder;
          inherit package;
        };
      deps = {
        bash = tvp.packages.bash_5;
        coreutils = constructionTool "coreutils";
        helperPython = constructionTool "python";
        gnutar = constructionTool "tar";
        findutils = constructionTool "findutils";
        binutils = constructionTool "binutils";
        patchelf = constructionTool "patchelf";
        xz = constructionTool "xz";
        python = tvp.packages.python-build_3;
        perl = tvp.packages.perl_5;
        cmake = tvp.packages.cmake;
        ninja = tvp.packages.ninja;
        pkg-config = tvp.packages.pkg-config;
        zlib = tvp.packages.zlib_1;
        zstd = tvp.packages.zstd_1;
        libffi = tvp.packages.libffi_3;
        libxml2 = tvp.packages.libxml2_2;
        rawGCC = tvp.packages.gcc_16;
        cxxRuntime = tvp.packages.gcc_16;
        gccRuntime = tvp.packages.gcc_16;
        libc = tvp.packages.glibc_2;
        targetBinutils = tvp.packages.binutils_2;
      };
      opts = {
        dynamicLinker = "lib/ld-linux-x86-64.so.2";
      };
    };
  };
  versionTable = constructionRecipe.versionTable // {
    "23.1.4" = constructionRecipe.versionTable."23.1.4" // {
      def =
        if pkgs.stdenv.hostPlatform.system == "x86_64-linux" then
          defs."23.1.4"
        else
          constructionRecipe.versionTable."23.1.4".def;
    };
  };
  publicArgs = constructionRecipe // {
    inherit versionTable;
    extraArgs.mkTests =
      package:
      if package ? testContext then
        import ./tests/native-default.nix { inherit package; }
      else
        constructionRecipe.extraArgs.mkTests package;
  };
  canonical = tvpLib.packages.mkVersions publicArgs;
  pname = "llvm";
in
{
  recipes.${pname} = publicArgs // {
    inherit constructionRecipe;
  };
  inherit canonical;
  aliases = tvpLib.packages.mkAliases { inherit pname versionTable canonical; } // {
    clang = canonical.llvm_23_1_4;
    clang_23_1_4 = canonical.llvm_23_1_4;
    lld = canonical.llvm_23_1_4;
    lld_23_1_4 = canonical.llvm_23_1_4;
  };
}

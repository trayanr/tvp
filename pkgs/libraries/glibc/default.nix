{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  defs = tvpLib.packages.mkDefs {
    "2.39" = {
      builder = ./build-2.39.nix;
      base = tvp.bases.default;
      deps = {
        gcc = tvp.packages.gcc;
        binutils = tvp.packages.binutils_2;
        linuxHeaders = tvp.packages.linux-headers;
        perl = tvp.packages.perl_5;
        bison = tvp.packages.bison;
        python3Minimal = tvp.packages.python-minimal_3;
      };
      patches = [
        {
          file = ./patches/store-cache.patch;
          reason = "Store-layout adaptation: resolve ld.so.cache and ld.so.conf inside this glibc's prefix instead of the host /etc. From nixpkgs 12228ff1752d7b7624a54e9c1af4b222b3c1073b, dont-use-system-ld-so-cache.patch; no stable-branch fixes applied.";
        }
      ];
    };
  };
  versionTable = tvpLib.packages.mkTable [
    {
      def = defs."2.39";
      releases."2.39" = "sha256-93vUfPgXDFc2Wue/hmlsEYrbOxINMlnGTFAtPcHi2SY=";
    }
  ];
  pname = "glibc";
  packageArgs = {
    infra = {
      inherit (pkgs) lib fetchurl;
      inherit (tvpLib) platforms;
    };
    inherit pname versionTable;
    extraArgs.mkTests = pkgs.lib.makeOverridable (
      { pkgs }: glibc: import ./tests { inherit pkgs tvpLib glibc; }
    ) { inherit pkgs; };
  };
  constructionRecipe = packageArgs;
  candidate = import ../../../bases/source-gnu { };
  constructionTool =
    name:
    tvpLib.packages.withConstraint {
      category = "construction";
      reason = "Retained source-GNU ${name} constructs libc independently of the future public shell/tool runtime, avoiding libc prerequisite cycles.";
    } candidate.tools.${name};
  ownedDef =
    (tvpLib.packages.mkDefs {
      "2.39" = {
        constructor = tvp.builder;
        builder = ./native/build-2.39.nix;
        base = candidate.base;
        helpers = {
          inherit tvp;
          inherit (tvpLib) platforms;
        };
        source =
          { version, sha256 }:
          import <nix/fetchurl.nix> {
            url = "https://mirrors.kernel.org/gnu/glibc/glibc-${version}.tar.xz";
            inherit sha256;
          };
        testContext =
          package:
          tvpLib.tests.fromPackage {
            builder = tvp.builder;
            inherit package;
          };
        deps = {
          bash = constructionTool "bash";
          coreutils = constructionTool "coreutils";
          gnumake = constructionTool "make";
          gnutar = constructionTool "tar";
          xz = constructionTool "xz";
          gzip = constructionTool "gzip";
          patch = constructionTool "patch";
          findutils = constructionTool "findutils";
          sed = constructionTool "sed";
          grep = constructionTool "grep";
          gawk = constructionTool "gawk";
          diffutils = constructionTool "diffutils";
          # Ordinary raw GCC is qualified; its libc stays explicitly pinned.
          gcc = tvp.packages.gcc;
          binutils = tvp.packages.binutils_2;
          linuxHeaders = tvp.packages.linux-headers;
          bison = tvp.packages.bison;
          python3Minimal = tvp.packages.python-minimal_3;
          perl = constructionTool "perl";
        };
        patches = [
          {
            file = ./patches/store-cache.patch;
            reason = "Retain per-store ld.so.cache and ld.so.conf, including loader diagnostics, instead of host /etc.";
          }
          {
            file = ./patches/fnmatch-gcc16.patch;
            reason = "GCC16 -O2 diagnoses four already documented fnmatch false positives outside the old -Os suppression. Extend those local diagnostic regions, as qualified in the source-GNU bootstrap reference.";
          }
        ];
      };
    })."2.39";
  publicArgs = packageArgs // {
    versionTable = versionTable // {
      "2.39" = versionTable."2.39" // {
        def = if pkgs.stdenv.hostPlatform.system == "x86_64-linux" then ownedDef else defs."2.39";
      };
    };
    extraArgs.mkTests = pkgs.lib.makeOverridable (
      { pkgs }:
      package:
      if package ? testContext then
        import ./tests/native.nix { inherit package; }
      else
        (constructionRecipe.extraArgs.mkTests.override { inherit pkgs; }) package
    ) { inherit pkgs; };
  };
  canonical = tvpLib.packages.mkVersions publicArgs;

in
{
  recipes.${pname} = publicArgs // {
    inherit constructionRecipe;
  };
  inherit canonical;
  aliases = tvpLib.packages.mkAliases { inherit pname versionTable canonical; };
}

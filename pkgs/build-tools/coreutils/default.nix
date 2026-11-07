{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  defs = tvpLib.packages.mkDefs {
    "9.5" = {
      builder = ./build-9.5.nix;
      base = tvp.bases.default;
      deps = {
        gmp = tvp.packages.gmp_6;
        acl = tvp.packages.acl_2;
      };
    };
  };
  versionTable = tvpLib.packages.mkTable [
    {
      def = defs."9.5";
      releases."9.5" = "sha256-zTKO3qyS9qZl3p8yPJO3Eq8YWLwuDYjz9xAEaUcKG4o=";
    }
  ];
  pname = "coreutils";
  packageArgs = {
    infra = {
      inherit (pkgs) lib fetchurl;
    };
    inherit pname versionTable;
    extraArgs.mkTests = package: import ./tests { inherit pkgs tvpLib package; };
  };
  # Complete capture, including the old table and test/source factories.
  constructionRecipe = packageArgs;
  candidate = import ../../../bases/source-gnu { };
  native = pkgs.stdenv.hostPlatform.system == "x86_64-linux";
  constructionTool =
    name:
    tvpLib.packages.withConstraint {
      category = "construction";
      reason = "Retained source-GNU ${name} is a build-only host generation; ordinary Coreutils/Tar consume the target libraries used to construct these tools.";
    } candidate.tools.${name};
  ownedDefs = tvpLib.packages.mkDefs {
    "9.5" = {
      constructor = tvp.builder;
      builder = ./native/build-9.5.nix;
      base = candidate.base;
      source =
        { version, sha256 }:
        import <nix/fetchurl.nix> {
          url = "https://mirrors.kernel.org/gnu/coreutils/coreutils-${version}.tar.xz";
          inherit sha256;
        };
      testContext =
        package:
        tvpLib.tests.fromPackage {
          builder = tvp.builder;
          inherit package;
        };
      helpers = { inherit tvp; };
      deps = {
        bash = constructionTool "bash";
        coreutils = constructionTool "coreutils";
        gnumake = constructionTool "make";
        gnutar = constructionTool "tar";
        xz = constructionTool "xz";
        python = constructionTool "python";
        perl = constructionTool "perl";
        binutils = constructionTool "binutils";
        patchelf = constructionTool "patchelf";
        sed = constructionTool "sed";
        grep = constructionTool "grep";
        gawk = constructionTool "gawk";
        diffutils = constructionTool "diffutils";
        findutils = constructionTool "findutils";
        gmp = tvp.packages.gmp_6;
        acl = tvp.packages.acl_2;
      };
    };
  };
  publicArgs = packageArgs // {
    testDeps.locale = import ../../../lib/tests/gnu-locale.nix {
      builder = tvp.builder;
      base = candidate.base;
      inherit (candidate.tools)
        bash
        coreutils
        tar
        xz
        ;
      libc = candidate.toolchain.libc;
    };
    versionTable = versionTable // {
      "9.5" = versionTable."9.5" // {
        def = if native then ownedDefs."9.5" else versionTable."9.5".def;
      };
    };
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

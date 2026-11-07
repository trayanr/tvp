{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  defs = tvpLib.packages.mkDefs {
    "4.9" = {
      builder = ./build-4.9.nix;
      base = tvp.bases.default;
      deps = {
        acl = tvp.packages.acl_2;
      };
    };
  };
  versionTable = tvpLib.packages.mkTable [
    {
      def = defs."4.9";
      releases = {
        "4.9" = "sha256-biJrcy4c1zlGStaGK9Ghq6QteYKSLaelNRljHSSXUYE=";
        "4.10" = "sha256-uOchgrLslqNXTimYxHt6qmTMIM4ADY6awxPMB87PKMc=";
      };
    }
  ];
  pname = "gnused";
  packageArgs = {
    infra = {
      inherit (pkgs) lib fetchurl;
    };
    inherit pname versionTable;
    extraArgs.mkTests = package: import ./tests { inherit pkgs tvpLib package; };
    packageMeta.upstream = {
      type = "directory-index";
      url = "https://mirrors.kernel.org/gnu/sed/";
      # Capture whole filenames so signatures and archival README placeholders
      # cannot be mistaken for available tarballs by a partial regex match.
      pattern = "sed-[0-9][^\"<>[:space:]]*";
      normalise =
        file:
        let
          matched = builtins.match "sed-([0-9]+(\\.[0-9]+)*)\\.tar\\.(gz|xz|bz2|lz)" file;
        in
        if matched == null then null else builtins.head matched;
      include = version: builtins.match "[0-9]+(\\.[0-9]+)*" version != null;
    };
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
    "4.10" = {
      constructor = tvp.builder;
      builder = ./native/build-4.10.nix;
      base = candidate.base;
      source =
        { version, sha256 }:
        import <nix/fetchurl.nix> {
          url = "https://mirrors.kernel.org/gnu/sed/sed-${version}.tar.xz";
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
        acl = tvp.packages.acl_2;
      };
    };
  };
  publicArgs = packageArgs // {
    extraArgs.mkTests =
      package:
      packageArgs.extraArgs.mkTests package
      // pkgs.lib.optionalAttrs (package ? testContext) (
        import ../../../lib/tests/command-source-edit.nix { inherit tvp package; }
      );
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
      "4.10" = versionTable."4.10" // {
        def = if native then ownedDefs."4.10" else versionTable."4.10".def;
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

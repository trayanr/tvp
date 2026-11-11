{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  defs = tvpLib.packages.mkDefs {
    "3.11" = {
      builder = ./build-3.11.nix;
      base = tvp.bases.default;
      deps = {
        pcre2 = tvp.packages.pcre2_10;
      };
    };
  };
  versionTable = tvpLib.packages.mkTable [
    {
      def = defs."3.11";
      releases = {
        "3.11" = "sha256-HbKu3eidDepCsW2VKPiUyNFdrk4ZC1muzHj1qVEnbqs=";
        "3.12" = "sha256-JkmyfA6Q5jLq3NdXvgbG6aT0jZQd5R58D4P/dkCKB7k=";
      };
    }
  ];
  pname = "gnugrep";
  packageArgs = {
    infra = {
      inherit (pkgs) lib fetchurl;
    };
    inherit pname versionTable;
    extraArgs.mkTests =
      package:
      import ./tests {
        inherit pkgs tvpLib package;
        locale = tvp.packages.glibc_2;
      };
    packageMeta.upstream = {
      type = "directory-index";
      url = "https://mirrors.kernel.org/gnu/grep/";
      # Capture the entire filename, including suffixes, before validating it.
      pattern = ''[^"<>/[:space:]]+\.tar\.[^"<>/[:space:]]+'';
      normalise =
        file:
        let
          archive = builtins.match "grep-([0-9]+(\\.[0-9]+)+)\\.tar\\.(gz|bz2|xz)" file;
        in
        if archive == null then null else builtins.head archive;
    };
  };
  # Complete legacy call: table, factories, source construction and test routing.
  constructionRecipe = packageArgs;
  candidate = import ../../../bases/source-gnu { };
  native = pkgs.stdenv.hostPlatform.system == "x86_64-linux";
  constructionTool =
    name:
    tvpLib.packages.withConstraint {
      category = "construction";
      reason = "Retained source-GNU ${name} is an explicit build-only host generation, independent of these target libraries and commands.";
    } candidate.tools.${name};
  ownedDefs = tvpLib.packages.mkDefs {
    "3.11" = {
      constructor = tvp.builder;
      builder = ./ordinary/build-3.11.nix;
      base = candidate.base;
      source =
        { version, sha256 }:
        import <nix/fetchurl.nix> {
          url = "https://mirrors.kernel.org/gnu/grep/grep-${version}.tar.xz";
          inherit sha256;
        };
      testContext =
        package:
        tvpLib.tests.fromPackage {
          builder = tvp.builder;
          inherit package;
        };
      helpers = {
        inherit tvp;
      };
      deps = {
        bash = constructionTool "bash";
        coreutils = constructionTool "coreutils";
        gnumake = constructionTool "make";
        gnutar = constructionTool "tar";
        python = constructionTool "python";
        perl = constructionTool "perl";
        binutils = constructionTool "binutils";
        patchelf = constructionTool "patchelf";
        sed = constructionTool "sed";
        grep = constructionTool "grep";
        gawk = constructionTool "gawk";
        diffutils = constructionTool "diffutils";
        findutils = constructionTool "findutils";
        xz = constructionTool "xz";
        pcre2 = tvp.packages.pcre2_10;
      };
    };
    "3.12" = {
      constructor = tvp.builder;
      builder = ./native/build-3.12.nix;
      base = candidate.base;
      source =
        { version, sha256 }:
        import <nix/fetchurl.nix> {
          url = "https://mirrors.kernel.org/gnu/grep/grep-${version}.tar.xz";
          inherit sha256;
        };
      testContext =
        package:
        tvpLib.tests.fromPackage {
          builder = tvp.builder;
          inherit package;
        };
      helpers = {
        inherit tvp;
      };
      deps = {
        bash = constructionTool "bash";
        coreutils = constructionTool "coreutils";
        gnumake = constructionTool "make";
        gnutar = constructionTool "tar";
        python = constructionTool "python";
        binutils = constructionTool "binutils";
        patchelf = constructionTool "patchelf";
        sed = constructionTool "sed";
        grep = constructionTool "grep";
        gawk = constructionTool "gawk";
        diffutils = constructionTool "diffutils";
        findutils = constructionTool "findutils";
        xz = constructionTool "xz";
        pcre2 = tvp.packages.pcre2_10;
      };
    };
  };
  locale = import ../../../lib/tests/gnu-locale.nix {
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
  publicArgs = packageArgs // {
    versionTable = versionTable // {
      "3.11" = versionTable."3.11" // {
        def = if native then ownedDefs."3.11" else versionTable."3.11".def;
      };
      "3.12" = versionTable."3.12" // {
        def = if native then ownedDefs."3.12" else versionTable."3.12".def;
      };
    };
    extraArgs.mkTests =
      package:
      if package ? testContext then
        import ./tests/native-default.nix {
          inherit pkgs tvpLib package;
          inherit locale;
        }
      else
        constructionRecipe.extraArgs.mkTests package;
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

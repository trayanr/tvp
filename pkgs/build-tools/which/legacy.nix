{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  defs = tvpLib.packages.mkDefs {
    "2.21" = {
      builder = ./build-2.21.nix;
      base = tvp.bases.default;
      deps = { };
    };
  };
  versionTable = tvpLib.packages.mkTable [
    {
      def = defs."2.21";
      releases."2.21" = "sha256-9KJFuUEks3fYtJZGv0IfkVXTaqdhS26/g3BdP/x26q0=";
    }
  ];
  pname = "which";
  packageArgs = {
    infra = {
      inherit (pkgs) lib fetchurl;
    };
    inherit pname versionTable;
    extraArgs.mkTests = pkgs.lib.makeOverridable (
      { pkgs }:
      package:
      import ./tests {
        inherit tvpLib package;
        pkgs = tvpLib.tests.withBase {
          inherit pkgs;
          base.stdenv = package.stdenv;
        };
      }
    ) { inherit pkgs; };
  };
  completed = tvp.bases.default;
  seed =
    reason:
    tvpLib.packages.withConstraint {
      category = "construction";
      inherit reason;
    };
  ownedDefs = tvpLib.packages.mkDefs {
    "2.21" = {
      constructor = tvp.builder;
      builder = ./owned/build-2.21.nix;
      base = completed;
      helpers = {
        inherit tvp;
      };
      deps = {
        bash = tvp.packages.bash_5;
        coreutils = tvp.packages.coreutils_9;
        gnumake = tvp.packages.gnumake_4;
        gnutar = tvp.packages.gnutar_1;
        gzip = tvp.packages.gzip_1;
        python = seed "Build-only completed libc construction interpreter for explicit source and output operations; avoids rebuilding the unported Python helper through this tool wave." completed.components.libc.tvp.deps.python3Minimal;
        binutils = tvp.packages.binutils_2;
        patchelf = tvp.packages.patchelf_0;
      };
    };
  };
  publicVersionTable = versionTable // {
    "2.21" = versionTable."2.21" // {
      def = ownedDefs."2.21";
    };
  };
  source =
    { version, sha256 }:
    pkgs.fetchurl {
      url = "https://mirrors.kernel.org/gnu/which/which-${version}.tar.gz";
      inherit sha256;
    };
  publicArgs = packageArgs // {
    versionTable = publicVersionTable;
    inherit source;
    extraArgs.mkTests = pkgs.lib.makeOverridable (
      { pkgs }:
      package:
      packageArgs.extraArgs.mkTests.override { inherit pkgs; } package
      // import ./tests/owned.nix {
        inherit tvpLib package;
        pkgs = tvpLib.tests.withBase {
          inherit pkgs;
          base.stdenv = package.stdenv;
        };
      }
    ) { inherit pkgs; };
  };
  # Preserve the exact prior definition and test constructor for frozen bases.
  constructionRecipe = packageArgs;
  canonical = tvpLib.packages.mkVersions publicArgs;

in
{
  recipes.${pname} = publicArgs // {
    inherit constructionRecipe;
  };
  inherit canonical;
  aliases = tvpLib.packages.mkAliases { inherit pname versionTable canonical; };
}

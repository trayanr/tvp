{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  base = tvp.bases.default;
  seed =
    reason:
    tvpLib.packages.withConstraint {
      category = "construction";
      inherit reason;
    };
  floorTool =
    name:
    seed
      "Completed default-base ${name} is a build-only seed for the foundational tool wave; it avoids following the canonical tool graph while rebuilding its prerequisites."
      base.components.floor.${name};
  defs = tvpLib.packages.mkDefs {
    "2.7.6" = {
      builder = ./build-2.7.6.nix;
      base = tvp.bases.default;
      deps = {

      };
    };
    "2.8.1" = {
      constructor = tvp.builder;
      builder = ./owned/build-2.8.1.nix;
      inherit base;
      helpers = {
        inherit tvp;
      };
      deps = {
        gzip = tvp.packages.gzip_1;
        bash = tvp.packages.bash_5;
        coreutils = floorTool "coreutils";
        gnumake = tvp.packages.gnumake;
        gnutar = floorTool "gnutar";
        xz = floorTool "xz";
        python = seed "Completed libc-build helper interpreter is build-only; using its existing recipe output avoids a new Python prerequisite cycle." base.components.libc.tvp.deps.python3Minimal;
        binutils = seed "Completed base Binutils supplies build-only output inspection and stripping without following its canonical prerequisite graph." base.components.binutils;
        patchelf = seed "Completed base Patchelf supplies build-only ELF finalization before the canonical Patchelf advance." base.fixupTools.patchelf;

      };
    };
  };
  versionTable = tvpLib.packages.mkTable [
    {
      def = defs."2.7.6";
      releases = {
        "2.7.6" = "sha256-rGEL2per4Nn2t8ljJVoR3LGWwl4zfGH5Tkd41jLx2P0=";
        "2.8" = "sha256-+Hzuae7CtPy/YKOWsDCtaqNBXxkqpffuhMrV4R9/WuM=";
      };
    }
    {
      def = defs."2.8.1";
      releases."2.8.1" = "sha256-MkDHlZxTR8jtNH48QgHAM3v0JA1c8J1oiJ5Y7qujDhc=";
    }
  ];
  pname = "patch";
  packageArgs = {
    infra = {
      inherit (pkgs) lib fetchurl;
    };
    inherit pname versionTable;
    extraArgs.mkTests = package: import ./tests { inherit pkgs tvpLib package; };
    packageMeta.upstream = {
      type = "directory-index";
      url = "https://mirrors.kernel.org/gnu/patch/";
      # Older releases use gzip; discover each stable version across formats.
      # The adapter deduplicates archive/signature matches after normalisation.
      pattern = "patch-[0-9]+(\\.[0-9]+)*\\.tar\\.(gz|bz2|xz|lz|zst|Z)";
      normalise =
        file:
        let
          match = builtins.match "patch-([0-9]+(\\.[0-9]+)*)\\.tar\\.(gz|bz2|xz|lz|zst|Z)" file;
        in
        if match == null then null else builtins.head match;
    };
  };
  constructionRecipe = packageArgs // {
    versionTable = versionTable // {
      "2.8.1" = versionTable."2.8.1" // {
        def = defs."2.7.6";
      };
    };
  };
  publicArgs = packageArgs // {
    source =
      { version, sha256 }:
      pkgs.fetchurl {
        url = "https://mirrors.kernel.org/gnu/patch/patch-${version}.tar.xz";
        inherit sha256;
      };
    extraArgs.mkTests =
      package:
      packageArgs.extraArgs.mkTests package
      // pkgs.lib.optionalAttrs (package.version == "2.8.1") (
        import ./tests/owned.nix {
          inherit tvp tvpLib package;
          pkgs = tvpLib.tests.withBase {
            inherit pkgs;
            base.stdenv = package.stdenv;
          };
        }
      );
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

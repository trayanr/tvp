{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  defs = tvpLib.packages.mkDefs {
    "0.19.2" = {
      builder = ./trimmed/build-0.19.2.nix;
      base = tvp.bases.default;
      deps = { };
    };
  };
  pname = "patchelf";
  versionTable = tvpLib.packages.mkTable [
    {
      def = defs."0.19.2";
      releases."0.19.2" = "sha256-1K2aTlxongkRnOLzCpSw6LT5jHhZASPqIWZeNMaSiAE=";
    }
  ];
  packageArgs = {
    infra = {
      inherit (pkgs) lib fetchurl;
    };
    inherit pname versionTable;
    extraArgs.mkTests =
      package:
      import ./tests {
        inherit tvpLib package;
        pkgs = tvpLib.tests.withBase {
          inherit pkgs;
          base.stdenv = package.stdenv;
        };
      };
  };
  # Full historical construction and its test factory remain independently selected.
  constructionRecipe = packageArgs;
  seed =
    name: value:
    tvpLib.packages.withConstraint {
      category = "construction";
      reason = "Build-only completed gcc16-owned ${name}; Patchelf cannot finalize itself or pull a helper interpreter through its own reverse dependencies.";
    } value;
  base = tvp.bases.default;
  source =
    { version, sha256 }:
    pkgs.fetchurl {
      url = "https://github.com/NixOS/patchelf/releases/download/${version}/patchelf-${version}.tar.bz2";
      inherit sha256;
    };
  publicArgs = packageArgs // {
    inherit source;
    extraArgs.mkTests =
      package:
      packageArgs.extraArgs.mkTests package
      // import ./tests/legacy-owned.nix {
        inherit tvp tvpLib package;
        pkgs = tvpLib.tests.withBase {
          inherit pkgs;
          base.stdenv = package.stdenv;
        };
      };
    versionTable = versionTable // {
      "0.19.2" = versionTable."0.19.2" // {
        def = defs."0.19.2" // {
          constructor = tvp.builder;
          builder = ./owned/build-0.19.2.nix;
          helpers = {
            inherit tvp;
          };
          deps = {
            inherit (tvp.packages)
              gzip
              bash
              gnumake
              gnutar
              bzip2
              ;
            coreutils = seed "Coreutils to break M4 -> Patchelf -> Coreutils -> GMP -> M4" base.components.floor.coreutils;
            python = seed "helper interpreter" base.components.libc.tvp.deps.python3Minimal;
            binutils = seed "ELF inspector" base.components.binutils;
            patchelf = seed "different ELF finalizer" base.fixupTools.patchelf;
            cxxRuntime = tvpLib.packages.withConstraint {
              category = "construction";
              reason = "Runtime libraries must match the completed gcc16-owned C++ compiler that links this executable.";
            } base.components.gcc;
          };
        };
      };
    };
  };
  canonical = tvpLib.packages.mkVersions publicArgs;

in
{
  recipes.${pname} = publicArgs // {
    inherit constructionRecipe;
    constructionBuilder = ./build-0.19.2.nix;
  };
  inherit canonical publicArgs;
  aliases = tvpLib.packages.mkAliases { inherit pname versionTable canonical; };
}

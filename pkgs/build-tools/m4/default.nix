{ pkgs, tvp }:
let
  tvpLib = tvp.lib;

  defs = tvpLib.packages.mkDefs {
    "1.4.17" = {
      builder = ./build-1.4.17.nix;
      base = tvp.bases.default;
      deps = { };
    };
    "1.4.19" = {
      builder = ./build-1.4.17.nix;
      base = tvp.bases.default;
      deps = { };
      # Bundled gnulib puts the C23 nodiscard attribute after inline. GNU17
      # retains its supported GNU attribute form; 1.4.20 fixes the placement.
      opts.cStandard = "gnu17";
    };
    "1.4.21" = {
      builder = ./build-1.4.17.nix;
      base = tvp.bases.default;
      deps = { };
    };
  };

  versionTable = tvpLib.packages.mkTable (import ./1.nix { inherit defs; });

  pname = "m4";

  packageArgs = {
    infra = {
      inherit (pkgs) lib fetchurl;
    };
    inherit pname;
    inherit versionTable;

    extraArgs = {
      mkTests = pkgs.lib.makeOverridable (
        { pkgs }:
        m4:
        import ./tests {
          inherit tvpLib m4;
          pkgs = tvpLib.tests.withBase {
            inherit pkgs;
            base.stdenv = m4.stdenv;
          };
        }
      ) { inherit pkgs; };
    };

    packageMeta = {
      upstream = {
        type = "directory-index";
        url = "https://mirrors.kernel.org/gnu/m4/";
        pattern = "m4-[0-9][^\"]*\\.tar\\.gz";

        normalise =
          file:
          if pkgs.lib.hasPrefix "m4-" file && pkgs.lib.hasSuffix ".tar.gz" file then
            pkgs.lib.removeSuffix ".tar.gz" (pkgs.lib.removePrefix "m4-" file)
          else
            null;

        include = version: builtins.match "[0-9].*" version != null;
      };
    };
  };

  completed = tvp.bases.default;
  seed =
    reason:
    tvpLib.packages.withConstraint {
      category = "construction";
      inherit reason;
    };
  ownedDefs = tvpLib.packages.mkDefs {
    "1.4.21" = {
      constructor = tvp.builder;
      builder = ./owned/build-1.4.21.nix;
      base = completed;
      helpers = {
        inherit tvp;
      };
      deps = {
        bash = tvp.packages.bash_5;
        coreutils = seed "Build-only completed Coreutils: selecting canonical Coreutils would close M4 -> Coreutils -> GMP -> M4." completed.components.floor.coreutils;
        gnumake = tvp.packages.gnumake_4;
        gnutar = tvp.packages.gnutar_1;
        gzip = tvp.packages.gzip_1;
        python = seed "Build-only completed libc construction interpreter for explicit source and output operations; avoids rebuilding the unported Python helper through this tool wave." completed.components.libc.tvp.deps.python3Minimal;
        binutils = seed "Build-only completed binutils for ELF finalization: canonical binutils needs Bison, which needs M4." completed.components.binutils;
        patchelf = tvp.packages.patchelf_0;
      };
    };
  };
  publicVersionTable = versionTable // {
    "1.4.21" = versionTable."1.4.21" // {
      def = ownedDefs."1.4.21";
    };
  };
  source =
    { version, sha256 }:
    pkgs.fetchurl {
      urls = [
        "https://mirrors.kernel.org/gnu/m4/m4-${version}.tar.gz"
        "https://ftp.gnu.org/gnu/m4/m4-${version}.tar.gz"
      ];
      inherit sha256;
    };
  publicArgs = packageArgs // {
    versionTable = publicVersionTable;
    inherit source;
    extraArgs.mkTests = pkgs.lib.makeOverridable (
      { pkgs }:
      package:
      packageArgs.extraArgs.mkTests.override { inherit pkgs; } package
      // pkgs.lib.optionalAttrs (package.version == "1.4.21") (
        import ./tests/owned.nix {
          inherit tvp tvpLib package;
          pkgs = tvpLib.tests.withBase {
            inherit pkgs;
            base.stdenv = package.stdenv;
          };
        }
      )
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
  aliases = tvpLib.packages.mkAliases {
    inherit
      pname
      versionTable
      canonical
      ;
  };
}

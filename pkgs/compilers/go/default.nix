{ pkgs, tvp }:
let
  # The retained chain has its own complete canonical fixed point.
  previous = import ./legacy.nix {
    inherit pkgs;
    tvp = tvp // {
      canonical = tvp.canonical // construction;
    };
  };
  retained = previous.publicArgs;
  construction = tvp.lib.packages.mkVersions retained;
  # Preserve the existing actual public Bash tool generation in this host base.
  compilerHostBase = tvp.baseTiers.full.override { shell = tvp.packages.bash_5; };
  pname = "go";
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build-owned-1.17.13.nix;
        base = compilerHostBase;
        deps.bootstrap = tvp.lib.packages.withConstraint {
          category = "construction";
          reason = "Explicit source-built preceding Go release; the public old ladder is independent of the retained construction ladder.";
        } (import ../go-bootstrap/legacy.nix { inherit pkgs tvp; }).canonical.go-bootstrap_20171003;
        opts = {
          goOS = "linux";
          goArch = "amd64";
          dynamicLinker = "lib/ld-linux-x86-64.so.2";
        };
      };
      releases."1.17.13" = "sha256-oaSLI6+yBvlee7qpuJjZZfkIJvbx0fwMHXhK2gzTAP0=";
    }
    {
      def = {
        builder = ./build-owned-1.17.13.nix;
        base = compilerHostBase;
        deps.bootstrap = tvp.lib.packages.withConstraint {
          category = "construction";
          reason = "Explicit source-built preceding Go release; the public old ladder is independent of the retained construction ladder.";
        } tvp.packages.go_1_17_13;
        opts = {
          goOS = "linux";
          goArch = "amd64";
          dynamicLinker = "lib/ld-linux-x86-64.so.2";
        };
      };
      releases."1.20.14" = "sha256-Gu8yGg4+OLfpHS1+tkBAZmyr3Md9OD3jyVItDWm2f04=";
    }
    {
      def = {
        builder = ./build-owned-1.22.12.nix;
        base = compilerHostBase;
        deps.bootstrap = tvp.lib.packages.withConstraint {
          category = "construction";
          reason = "Explicit source-built preceding Go release; the public old ladder is independent of the retained construction ladder.";
        } tvp.packages.go_1_20_14;
        opts = {
          goOS = "linux";
          goArch = "amd64";
          dynamicLinker = "lib/ld-linux-x86-64.so.2";
        };
      };
      releases."1.22.12" = "sha256-ASp+HzfzYsCRjB36MzRFisLaFijEuc9NnKAtuYbhfXE=";
    }
    {
      def = {
        builder = ./build-owned-1.22.12.nix;
        base = compilerHostBase;
        deps.bootstrap = tvp.lib.packages.withConstraint {
          category = "construction";
          reason = "Explicit source-built preceding Go release; the public old ladder is independent of the retained construction ladder.";
        } tvp.packages.go_1_22_12;
        opts = {
          goOS = "linux";
          goArch = "amd64";
          dynamicLinker = "lib/ld-linux-x86-64.so.2";
        };
      };
      releases."1.24.13" = "sha256-Y5piBMJIaxN98etueO4+0Dj5h30OS1pGXnlqIVP4WNc=";
    }
    {
      def = {
        builder = ./build-owned-1.27.3.nix;
        base = compilerHostBase;
        deps.bootstrap = tvp.lib.packages.withConstraint {
          category = "construction";
          reason = "Exact retained source-built Go 1.24.13 seed; no bootstrap chain rebuild in the direct latest procedure.";
        } construction.go_1_24_13;
        opts = {
          goOS = "linux";
          goArch = "amd64";
          dynamicLinker = "lib/ld-linux-x86-64.so.2";
        };
      };
      releases."1.27.3" = "sha256-bndJA1zzYPBrJXXRYup535/ajvZxiJ5cN1+OUHd/Jrs=";
    }
  ];
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable;
    packageMeta = retained.packageMeta or { };
    source =
      { version, sha256 }:
      pkgs.fetchurl {
        url = "https://dl.google.com/go/go${version}.src.tar.gz";
        inherit sha256;
      };
    tests = import ./tests/installed.nix;
  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes.go = family // {
    constructionRecipe = retained;
  };
  inherit canonical construction;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}

{ pkgs, tvp }:
let
  pname = "go";
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build-owned-1.17.13.nix;
        deps.bootstrap = tvp.lib.packages.withConstraint {
          category = "construction";
          reason = "Explicit source-built preceding Go release; each stage uses the current family procedure and the preceding canonical source compiler.";
        } tvp.packages.go-bootstrap_20171003;
      };
      releases."1.17.13" = "sha256-oaSLI6+yBvlee7qpuJjZZfkIJvbx0fwMHXhK2gzTAP0=";
    }
    {
      def = {
        builder = ./build-owned-1.17.13.nix;
        deps.bootstrap = tvp.lib.packages.withConstraint {
          category = "construction";
          reason = "Explicit source-built preceding Go release; each stage uses the current family procedure and the preceding canonical source compiler.";
        } tvp.packages.go_1_17_13;
      };
      releases."1.20.14" = "sha256-Gu8yGg4+OLfpHS1+tkBAZmyr3Md9OD3jyVItDWm2f04=";
    }
    {
      def = {
        builder = ./build-owned-1.22.12.nix;
        deps.bootstrap = tvp.lib.packages.withConstraint {
          category = "construction";
          reason = "Explicit source-built preceding Go release; each stage uses the current family procedure and the preceding canonical source compiler.";
        } tvp.packages.go_1_20_14;
      };
      releases."1.22.12" = "sha256-ASp+HzfzYsCRjB36MzRFisLaFijEuc9NnKAtuYbhfXE=";
    }
    {
      def = {
        builder = ./build-owned-1.22.12.nix;
        deps.bootstrap = tvp.lib.packages.withConstraint {
          category = "construction";
          reason = "Explicit source-built preceding Go release; each stage uses the current family procedure and the preceding canonical source compiler.";
        } tvp.packages.go_1_22_12;
      };
      releases."1.24.13" = "sha256-Y5piBMJIaxN98etueO4+0Dj5h30OS1pGXnlqIVP4WNc=";
    }
    {
      def = {
        builder = ./build-owned-1.27.3.nix;
        deps.bootstrap = tvp.lib.packages.withConstraint {
          category = "construction";
          reason = "Exact source-built Go 1.24.13 predecessor for the latest Go release; no duplicate retained bootstrap ladder.";
        } tvp.packages.go_1_24_13;
      };
      releases."1.27.3" = "sha256-bndJA1zzYPBrJXXRYup535/ajvZxiJ5cN1+OUHd/Jrs=";
    }
  ];
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable;
    packageMeta.upstream = {
      type = "git-tags";
      url = "https://github.com/golang/go";
      normalise = tag: if pkgs.lib.hasPrefix "go" tag then pkgs.lib.removePrefix "go" tag else null;
      include = version: builtins.match "[0-9]+\\.[0-9]+(\\.[0-9]+)?" version != null;
    };
    source =
      { version, sha256 }:
      import <nix/fetchurl.nix> {
        url = "https://dl.google.com/go/go${version}.src.tar.gz";
        inherit sha256;
      };
    tests = import ./tests/installed.nix;
  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes.go = family;
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}

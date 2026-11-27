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
        builder = ./build-1.22.0.nix;
        deps.bootstrap = tvp.lib.packages.withConstraint {
          category = "construction";
          reason = "Explicit source-built preceding Go release; each stage uses the current family procedure and the preceding canonical source compiler.";
        } tvp.packages.go_1_20_14;
      };
      releases = {
        "1.22.0" = "sha256-TRlsPUGg1sHfxk0E48wfYIsMQ2vYe3Bgzj4jI04fTVw=";
        "1.22.1" = "sha256-ecm5HX8QlRWiX8Ps2q0SXWfmvbVPbU2YWA9GeZyuoyE=";
        "1.22.2" = "sha256-N06oKyiexzjpaCZ8rFnH1f8YD5SSJQJUeEsgROkN9ak=";
        "1.22.3" = "sha256-gGSO80+QMZPXKlnA3/AZ9fmK4MmqE63gsOy/+ZGnb2g=";
        "1.22.4" = "sha256-/tcgZ45yinyjC6jR3tHKr+J9FgKPqwIyuLqOIgCPt4Q=";
        "1.22.5" = "sha256-rJxyPyJJaa7mJLw0/TTJ4T8qIS11xxyAfeZEu0bhEvY=";
        "1.22.6" = "sha256-nkjZnVGYgleZF9gYnBfpjDc84lq667mHcuKScIiZKlE=";
        "1.22.7" = "sha256-ZkMth9heDPrD7f/mN9WTD8Td9XkzE/4R5KDzMwI8h58=";
        "1.22.8" = "sha256-3xLCPr8Z3qD0v0aiLL7aSj7Kb0dPMYOQzndJdCeEQLg=";
        "1.22.9" = "sha256-6Bo2L1Gu4hJXIrAY5GcU5qBVoZVCg0FMD5N+c3AT2yI=";
        "1.22.10" = "sha256-HpT9SL51DR+vtNmztt0xpunSc10zm/JGK8l7ZMpMEDc=";
        "1.22.11" = "sha256-pgwj3sldEKJXYmXOWA9Xhp1awkccT0rKgFrdyeoPyf4=";
        "1.22.12" = "sha256-ASp+HzfzYsCRjB36MzRFisLaFijEuc9NnKAtuYbhfXE=";
      };
    }
    {
      def = {
        builder = ./build-1.22.0.nix;
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

    source = tvp.lib.sources.directory {
      url = "https://dl.google.com/go/";
      archive = "go{version}.src.tar.gz";
      discovery = {
        type = "git-tags";
        url = "https://github.com/golang/go";
        normalise = tag: if pkgs.lib.hasPrefix "go" tag then pkgs.lib.removePrefix "go" tag else null;
        include = version: builtins.match "[0-9]+\\.[0-9]+(\\.[0-9]+)?" version != null;
      };
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

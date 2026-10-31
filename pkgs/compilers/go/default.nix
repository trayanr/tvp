{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  platform = tvpLib.platforms.forStdenv tvp.bases.default.stdenv;
  defs = tvpLib.packages.mkDefs {
    "1.17.13" = {
      builder = ./build-1.17.13.nix;
      base = tvp.bases.default;
      deps = {
        bootstrap = (
          tvp.lib.packages.withConstraint {
            category = "construction";
            reason = "Explicit upstream bootstrap stage; preserve the released compiler seed and acyclic construction chain.";
          } tvp.canonical."go-bootstrap_20171003"
        );
        bash = tvp.packages.bash_5;
      };
      opts = {
        inherit (platform) goOS goArch dynamicLinker;
      };
    };
    "1.20.14" = {
      builder = ./build-1.17.13.nix;
      base = tvp.bases.default;
      deps = {
        bootstrap = (
          tvp.lib.packages.withConstraint {
            category = "construction";
            reason = "Explicit upstream bootstrap stage; preserve the released compiler seed and acyclic construction chain.";
          } tvp.canonical.go_1_17_13
        );
        bash = tvp.packages.bash_5;
      };
      opts = {
        inherit (platform) goOS goArch dynamicLinker;
      };
    };
    "1.22.12" = {
      builder = ./build-1.22.12.nix;
      base = tvp.bases.default;
      deps = {
        bootstrap = (
          tvp.lib.packages.withConstraint {
            category = "construction";
            reason = "Explicit upstream bootstrap stage; preserve the released compiler seed and acyclic construction chain.";
          } tvp.canonical.go_1_20_14
        );
        bash = tvp.packages.bash_5;
      };
      opts = {
        inherit (platform) goOS goArch dynamicLinker;
      };
    };
    "1.24.13" = {
      builder = ./build-1.22.12.nix;
      base = tvp.bases.default;
      deps = {
        bootstrap = (
          tvp.lib.packages.withConstraint {
            category = "construction";
            reason = "Explicit upstream bootstrap stage; preserve the released compiler seed and acyclic construction chain.";
          } tvp.canonical.go_1_22_12
        );
        bash = tvp.packages.bash_5;
      };
      opts = {
        inherit (platform) goOS goArch dynamicLinker;
      };
    };
    "1.27.3" = {
      builder = ./build-1.22.12.nix;
      base = tvp.bases.default;
      deps = {
        bootstrap = (
          tvp.lib.packages.withConstraint {
            category = "construction";
            reason = "Explicit upstream bootstrap stage; preserve the released compiler seed and acyclic construction chain.";
          } tvp.canonical.go_1_24_13
        );
        bash = tvp.packages.bash_5;
      };
      opts = {
        inherit (platform) goOS goArch dynamicLinker;
      };
    };
  };
  pname = "go";
  versionTable = tvpLib.packages.mkTable [
    {
      def = defs."1.17.13";
      releases."1.17.13" = "sha256-oaSLI6+yBvlee7qpuJjZZfkIJvbx0fwMHXhK2gzTAP0=";
    }
    {
      def = defs."1.20.14";
      releases."1.20.14" = "sha256-Gu8yGg4+OLfpHS1+tkBAZmyr3Md9OD3jyVItDWm2f04=";
    }
    {
      def = defs."1.22.12";
      releases."1.22.12" = "sha256-ASp+HzfzYsCRjB36MzRFisLaFijEuc9NnKAtuYbhfXE=";
    }
    {
      def = defs."1.24.13";
      releases."1.24.13" = "sha256-Y5piBMJIaxN98etueO4+0Dj5h30OS1pGXnlqIVP4WNc=";
    }
    {
      def = defs."1.27.3";
      releases."1.27.3" = "sha256-bndJA1zzYPBrJXXRYup535/ajvZxiJ5cN1+OUHd/Jrs=";
    }
  ];
  canonical = tvpLib.packages.mkVersions {
    infra = {
      inherit (pkgs) lib fetchurl;
    };
    inherit pname versionTable;
    packageMeta.upstream = {
      type = "git-tags";
      url = "https://github.com/golang/go";
      normalise = tag: if pkgs.lib.hasPrefix "go" tag then pkgs.lib.removePrefix "go" tag else null;
      include = version: builtins.match "[0-9]+\\.[0-9]+(\\.[0-9]+)?" version != null;
    };
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
in
{
  inherit canonical;
  aliases = tvpLib.packages.mkAliases { inherit pname versionTable canonical; };
}

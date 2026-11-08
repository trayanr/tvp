{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  defs = tvpLib.packages.mkDefs {
    "1.13.0" = {
      builder = ./build-1.13.0.nix;
      base = tvp.bases.default;
      deps = {
        python = tvp.packages.python-minimal_3;
        bash = tvp.packages.bash_5;
      };
      patches = [
        {
          file = ./patches/store-shell.patch;
          reason = "Store-layout adaptation: use the declared Bash instead of /bin/sh, which is absent in Nix build sandboxes.";
        }
      ];
    };
  };
  versionTable = tvpLib.packages.mkTable [
    {
      def = defs."1.13.0";
      releases = {
        "1.13.0" = "sha256-8IZB0ACZqeQNROwBRvhBxHKuWLfm3VF77jlFz9kjzt8=";
        "1.13.1" = "sha256-8AVa0Dab8uNylVulUSjQAM/MIXdwV4BgFbReSsy+vyM=";
        "1.13.2" = "sha256-l01rL07u+iViXTTaPLNr3Ovn+85A9MFqwINf0cDLrhc=";
      };
    }
  ];
  pname = "ninja";
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
    packageMeta.upstream = {
      type = "git-tags";
      url = "https://github.com/ninja-build/ninja.git";
      normalise = tag: pkgs.lib.removePrefix "v" tag;
      include = version: builtins.match "[0-9]+(\\.[0-9]+)*" version != null;
    };
  };
  # Complete prior family: source, patches, test factory and arguments remain
  # available to frozen construction and historical public test universes.
  constructionRecipe = packageArgs;
  candidate = import ../../../bases/source-gnu { };
  native = pkgs.stdenv.hostPlatform.system == "x86_64-linux";
  constructionTool =
    name:
    tvpLib.packages.withConstraint {
      category = "construction";
      reason = "Retained source-GNU ${name} host tool is independent of ordinary frontend consumers.";
    } candidate.tools.${name};
  ownedDefs = tvpLib.packages.mkDefs {
    "1.13.2" = {
      constructor = tvp.builder;
      builder = ./native/build-1.13.2.nix;
      base = candidate.base;
      source =
        { version, sha256 }:
        pkgs.fetchurl {
          url = "https://github.com/ninja-build/ninja/archive/refs/tags/v${version}.tar.gz";
          inherit sha256;
        };
      helpers = {
        inherit tvp;
      };
      testContext =
        package:
        tvpLib.tests.fromPackage {
          builder = tvp.builder;
          inherit package;
        };
      deps = {
        coreutils = constructionTool "coreutils";
        gnutar = constructionTool "tar";
        gzip = constructionTool "gzip";
        findutils = constructionTool "findutils";
        binutils = constructionTool "binutils";
        patchelf = constructionTool "patchelf";
        helperPython = constructionTool "python";
        patch = constructionTool "patch";
        sed = constructionTool "sed";
        python = tvp.packages.python_3;
        bash = tvp.packages.bash_5;
      };
      patches = [
        {
          file = ./patches/store-shell.patch;
          reason = "Bind subprocess commands to the selected Bash in store-only sandboxes.";
        }
      ];

    };
  };
  publicArgs = packageArgs // {
    versionTable = versionTable // {
      "1.13.2" = versionTable."1.13.2" // {
        def = if native then ownedDefs."1.13.2" else versionTable."1.13.2".def;
      };
    };
    extraArgs.mkTests = pkgs.lib.makeOverridable (
      { pkgs }:
      package:
      if package ? testContext then
        import ./tests/native-default.nix {
          inherit
            pkgs
            tvp
            tvpLib
            package
            ;
        }
      else
        constructionRecipe.extraArgs.mkTests package
    ) { inherit pkgs; };
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

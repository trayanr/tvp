{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  # Capture the complete old factory in its own canonical fixed point. This
  # includes table, defaults, tests and the exact legacy C-source seed import.
  previous = import ./legacy.nix {
    inherit pkgs;
    tvp = tvp // {
      canonical = tvp.canonical // construction;
    };
  };
  construction = tvpLib.packages.mkVersions constructionRecipe;
  constructionRecipe = previous.publicArgs;
  candidate = import ../../../bases/source-gnu { };
  constructionTool =
    name:
    tvpLib.packages.withConstraint {
      category = "construction";
      reason = "Retained source-GNU ${name} host tool; independent of the ordinary compiler payload.";
    } candidate.tools.${name};
  defs = tvpLib.packages.mkDefs {
    "1.27.3" = {
      constructor = tvp.builder;
      builder = ./native/build-1.27.3.nix;
      base = candidate.base;
      helpers = {
        inherit tvp;
      };
      source =
        { version, sha256 }:
        pkgs.fetchurl {
          url = "https://dl.google.com/go/go${version}.src.tar.gz";
          inherit sha256;
        };
      testContext =
        package:
        tvpLib.tests.fromPackage {
          builder = tvp.builder;
          inherit package;
        };
      deps = {
        bash = tvp.packages.bash_5;
        coreutils = constructionTool "coreutils";
        helperPython = constructionTool "python";
        gnutar = constructionTool "tar";
        findutils = constructionTool "findutils";
        binutils = constructionTool "binutils";
        patchelf = constructionTool "patchelf";
        gzip = constructionTool "gzip";
        grep = constructionTool "grep";
        sed = constructionTool "sed";
        bootstrap = tvpLib.packages.withConstraint {
          category = "construction";
          reason = "Exact retained source-built Go 1.24.13 seed; no bootstrap chain rebuild in the direct latest procedure.";
        } construction.go_1_24_13;
      };
      opts = {
        goOS = "linux";
        goArch = "amd64";
        dynamicLinker = "lib/ld-linux-x86-64.so.2";
      };
    };
  };
  oldVersions = [
    "1.17.13"
    "1.20.14"
    "1.22.12"
    "1.24.13"
  ];
  oldDefs = tvpLib.packages.mkDefs (
    builtins.listToAttrs (
      map (version: {
        name = version;
        value = {
          constructor = tvp.builder;
          builder =
            if pkgs.lib.versionOlder version "1.21" then
              ./ordinary/build-1.17.13.nix
            else
              ./ordinary/build-1.22.12.nix;
          base = candidate.base;
          helpers = { inherit tvp; };
          source =
            { version, sha256 }:
            pkgs.fetchurl {
              url = "https://dl.google.com/go/go${version}.src.tar.gz";
              inherit sha256;
            };
          testContext =
            package:
            tvpLib.tests.fromPackage {
              builder = tvp.builder;
              inherit package;
            };
          deps = {
            bash = tvp.packages.bash_5;
            coreutils = constructionTool "coreutils";
            helperPython = constructionTool "python";
            gnutar = constructionTool "tar";
            findutils = constructionTool "findutils";
            binutils = constructionTool "binutils";
            patchelf = constructionTool "patchelf";
            gzip = constructionTool "gzip";
            grep = constructionTool "grep";
            sed = constructionTool "sed";
            bootstrap =
              tvpLib.packages.withConstraint
                {
                  category = "construction";
                  reason = "Explicit source-built preceding Go release; the public old ladder is independent of the retained construction ladder.";
                }
                (
                  if version == "1.17.13" then
                    (import ../go-bootstrap/legacy.nix { inherit pkgs tvp; }).canonical.go-bootstrap_20171003
                  else if version == "1.20.14" then
                    canonical.go_1_17_13
                  else if version == "1.22.12" then
                    canonical.go_1_20_14
                  else
                    canonical.go_1_22_12
                );
          };
          opts = {
            goOS = "linux";
            goArch = "amd64";
            dynamicLinker = "lib/ld-linux-x86-64.so.2";
          };
        };
      }) oldVersions
    )
  );
  versionTable =
    constructionRecipe.versionTable
    // builtins.listToAttrs (
      map (version: {
        name = version;
        value = constructionRecipe.versionTable.${version} // {
          def =
            if pkgs.stdenv.hostPlatform.system == "x86_64-linux" then
              (if version == "1.27.3" then defs.${version} else oldDefs.${version})
            else
              constructionRecipe.versionTable.${version}.def;
        };
      }) (oldVersions ++ [ "1.27.3" ])
    );
  publicArgs = constructionRecipe // {
    inherit versionTable;
    extraArgs.mkTests =
      package:
      if package ? testContext then
        (import ./tests/native-default.nix { inherit package; })
        // pkgs.lib.optionalAttrs (package.specification ? upstreamFactory) {
          upstream-audit =
            (import package.specification.upstreamFactory {
              inherit package tvp;
              lib = pkgs.lib;
            }).acceptance;
        }
      else
        constructionRecipe.extraArgs.mkTests package;
  };
  canonical = tvpLib.packages.mkVersions publicArgs;
  pname = "go";
in
{
  recipes.${pname} = publicArgs // {
    inherit constructionRecipe;
  };
  inherit canonical construction;
  aliases = tvpLib.packages.mkAliases { inherit pname versionTable canonical; };
}

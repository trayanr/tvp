{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  previous = (import ./legacy.nix { inherit pkgs tvp; }).recipes.tcl;
  retained = previous.constructionRecipe;
  candidate = import ../../../bases/source-gnu { };
  native = pkgs.stdenv.hostPlatform.system == "x86_64-linux";
  constructionTool =
    name:
    tvpLib.packages.withConstraint {
      category = "construction";
      kind = "exact";
      namespace = "source-gnu.tools";
      selector = name;
      reason = "Retained source-GNU ${name} host tool, independent of ordinary Tcl.";
    } candidate.tools.${name};
  tools = {
    bash = constructionTool "bash";
    coreutils = constructionTool "coreutils";
    pkgConfig = constructionTool "pkgConfig";
    gnumake = constructionTool "make";
    gnutar = constructionTool "tar";
    python = constructionTool "python";
    binutils = constructionTool "binutils";
    patchelf = constructionTool "patchelf";
    sed = constructionTool "sed";
    grep = constructionTool "grep";
    gawk = constructionTool "gawk";
    diffutils = constructionTool "diffutils";
    findutils = constructionTool "findutils";
    gzip = constructionTool "gzip";
    patch = constructionTool "patch";
  };
  ordinary =
    def:
    def
    // {
      constructor = tvp.builder;
      builder = ./ordinary + "/${builtins.baseNameOf def.builder}";
      base = candidate.base;
      helpers = {
        inherit tvp;
      };
      # Preserve every original URL alternative, including the 8.0p2/8.1 names.
      source =
        { version, sha256 }:
        pkgs.fetchurl {
          urls =
            [
              "https://prdownloads.sourceforge.net/tcl/tcl${version}-src.tar.gz"
              "https://prdownloads.sourceforge.net/tcl/tcl${version}.tar.gz"
            ]
            ++ pkgs.lib.optionals (builtins.baseNameOf def.builder == "build-8.0.2.nix") [
              "https://prdownloads.sourceforge.net/tcl/tcl${pkgs.lib.versions.majorMinor version}p${pkgs.lib.versions.patch version}.tar.gz"
              "https://prdownloads.sourceforge.net/tcl/tcl${pkgs.lib.versions.majorMinor version}.tar.gz"
            ];
          inherit sha256;
        };
      testContext =
        package:
        tvpLib.tests.fromPackage {
          builder = tvp.builder;
          inherit package;
        };
      deps =
        def.deps
        // tools
        // pkgs.lib.optionalAttrs (builtins.baseNameOf def.builder == "build-8.6.0.nix") {
          libgcc = candidate.toolchain.runtime;
        };
    };
  versionTable = builtins.mapAttrs (
    version: entry:
    entry
    // {
      def =
        if !native then
          entry.def
        else if
          builtins.elem version [
            "8.6.18"
            "9.1.0"
          ]
        then
          previous.versionTable.${version}.def
          // {
            deps = previous.versionTable.${version}.def.deps // {
              patch = tools.patch;
            };
          }
          // pkgs.lib.optionalAttrs (version == "9.1.0") {
            patches = [ ];
            opts.testPatches = map (p: p.file) previous.versionTable.${version}.def.patches;
          }
        else
          ordinary entry.def;
    }
  ) retained.versionTable;
  publicArgs = retained // {
    inherit versionTable;
    extraArgs.mkTests = pkgs.lib.makeOverridable (
      { pkgs }:
      package:
      if package ? testContext then
        (import ./tests {
          inherit pkgs tvpLib;
          tcl = package;
          pkg-config = package.specification.testPkgConfig or package.tvp.declaredTestDependencies.pkg-config;
        })
        // pkgs.lib.optionalAttrs (package.version == "8.6.18") (
          import ./tests/native-contract.nix { inherit package; }
        )
        // pkgs.lib.optionalAttrs (package.version == "9.1.0") (
          import ./tests/native-contract-9.1.nix { inherit package; }
        )
        //
          pkgs.lib.optionalAttrs
            ((package.tvp.features.doCheck or false) && package.tvp.features.bundledPackages)
            {
              upstream = import ./tests/upstream.nix { inherit package; };
            }
      else
        (retained.extraArgs.mkTests.override { inherit pkgs; }) package
    ) { inherit pkgs; };
  };
  canonical = tvpLib.packages.mkVersions publicArgs;
  pname = "tcl";
in
{
  recipes.${pname} = publicArgs // {
    constructionRecipe = retained;
  };
  inherit canonical;
  aliases = tvpLib.packages.mkAliases { inherit pname versionTable canonical; };
}

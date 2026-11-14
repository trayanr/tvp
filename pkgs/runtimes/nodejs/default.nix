{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  previous = import ./legacy.nix { inherit pkgs tvp; };
  retained = previous.recipes.nodejs;
  candidate = import ../../../bases/source-gnu { };
  native = pkgs.stdenv.hostPlatform.system == "x86_64-linux";
  constructionTool =
    name:
    tvpLib.packages.withConstraint {
      category = "construction";
      kind = "exact";
      namespace = "source-gnu.tools";
      selector = name;
      reason = "Retained source-GNU ${name} host tool, independent of the ordinary target.";
    } candidate.tools.${name};
  ownedDefs = tvpLib.packages.mkDefs {
    "26.13.0" = {
      constructor = tvp.builder;
      builder = ./native/build-26.13.0.nix;
      base = candidate.base;
      helpers = {
        inherit tvp;
      };
      source =
        { version, sha256 }:
        import <nix/fetchurl.nix> {
          url = "https://nodejs.org/dist/v${version}/node-v${version}.tar.xz";
          inherit sha256;
        };
      testContext =
        package:
        tvpLib.tests.fromPackage {
          builder = tvp.builder;
          inherit package;
        };
      deps = {
        bash = constructionTool "bash";
        coreutils = constructionTool "coreutils";
        toolPython = constructionTool "python";
        gnumake = constructionTool "make";
        gnutar = constructionTool "tar";
        findutils = constructionTool "findutils";
        sed = constructionTool "sed";
        grep = constructionTool "grep";
        gawk = constructionTool "gawk";
        diffutils = constructionTool "diffutils";
        binutils = constructionTool "binutils";
        patchelf = constructionTool "patchelf";
        xz = constructionTool "xz";
        patch = constructionTool "patch";
        python = tvp.packages.python_3;
        ninja = tvp.packages.ninja;
        # The public 5.2.37 Bash output retains the compiler through bashbug.
        # This already-built source Bash supplies a compiler-free runtime shell.
        runtimeBash = constructionTool "bash";
        # Declared upstream binary build-only exceptions; source bootstrap pending.
        rustc = tvp.packages.rustc_1;
        cargo = tvp.packages.cargo-bootstrap_1;
        openssl = tvp.packages.openssl;
        zlib = tvp.packages.zlib_1;
      };
      patches = [
        {
          file = ./patches/store-shell.patch;
          reason = "Bind subprocess and npm shells to the explicitly selected Bash.";
        }
      ];
    };
  };
  versionTable = retained.versionTable // {
    "26.13.0" = retained.versionTable."26.13.0" // {
      def = if native then ownedDefs."26.13.0" else retained.versionTable."26.13.0".def;
    };
  };
  publicArgs = retained // {
    inherit versionTable;
    testDeps = {
      shell = tvp.packages.bash_5;
    };

    extraArgs.mkTests = pkgs.lib.makeOverridable (
      { pkgs }:
      package:
      if package ? testContext then
        import ./tests/native.nix { inherit pkgs tvpLib package; }
      else
        (retained.extraArgs.mkTests.override { inherit pkgs; }) package
    ) { inherit pkgs; };
  };
  canonical = tvpLib.packages.mkVersions publicArgs;
  pname = "nodejs";
in
{
  recipes.${pname} = publicArgs // {
    constructionRecipe = retained;
  };
  inherit canonical;
  aliases = tvpLib.packages.mkAliases { inherit pname versionTable canonical; };
}

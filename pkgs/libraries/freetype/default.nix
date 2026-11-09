{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  defs = tvpLib.packages.mkDefs {
    "2.15.0" = {
      builder = ./build-2.15.0.nix;
      base = tvp.bases.default;
      deps = {
        pkg-config = tvp.packages.pkg-config;
        zlib = tvp.packages.zlib_1;
        bzip2 = tvp.packages.bzip2_1;
        patchelf = tvp.packages.patchelf;
      };
    };
  };
  pname = "freetype";
  versionTable = tvpLib.packages.mkTable [
    {
      def = defs."2.15.0";
      releases."2.15.0" = "sha256-k81H63GcMlEH8tPPCH0GKZ6UTDtIpAtVU3MCME3qHdU=";
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
  # Ordinary native release only. Frozen construction retains the complete call.
  constructionRecipe = packageArgs;
  candidate = import ../../../bases/source-gnu { };
  native = pkgs.stdenv.hostPlatform.system == "x86_64-linux";
  constructionTool =
    name:
    tvpLib.packages.withConstraint {
      category = "construction";
      reason = "Retained source-GNU ${name} is an explicit build host tool, independent of this ordinary library target.";
    } candidate.tools.${name};
  ownedDefs = tvpLib.packages.mkDefs {
    "2.15.0" = {
      constructor = tvp.builder;
      builder = ./native/build-2.15.0.nix;
      base = candidate.base;
      source =
        { version, sha256 }:
        import <nix/fetchurl.nix> {
          url = "https://download.savannah.gnu.org/releases/freetype/freetype-${version}.tar.xz";
          inherit sha256;
        };
      helpers = { inherit tvp; };
      testContext =
        package:
        tvpLib.tests.fromPackage {
          builder = tvp.builder;
          inherit package;
        };
      deps = {
        bash = constructionTool "bash";
        coreutils = constructionTool "coreutils";
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
        xz = constructionTool "xz";
        pkgConfig = tvp.packages.pkg-config;
        zlib = tvp.packages.zlib_1;
        bzip2 = tvp.packages.bzip2_1;
      };
    };
  };
  publicArgs = packageArgs // {
    testDeps.gzip = constructionTool "gzip";
    versionTable = versionTable // {
      "2.15.0" = versionTable."2.15.0" // {
        def = if native then ownedDefs."2.15.0" else versionTable."2.15.0".def;
      };
    };
    extraArgs.mkTests = pkgs.lib.makeOverridable (
      { pkgs }:
      package:
      if package ? testContext then
        import ./tests/native.nix { inherit package; }
      else
        (
          package:
          import ./tests {
            inherit tvpLib package;
            pkgs = tvpLib.tests.withBase {
              inherit pkgs;
              base.stdenv = package.stdenv;
            };

          }
        )
          package
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

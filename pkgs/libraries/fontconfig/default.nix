{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  defs = tvpLib.packages.mkDefs {
    "2.18.3" = {
      constructor = tvp.builder;
      builder = ./build-2.18.3.nix;
      helpers = {
        inherit tvp;
      };
      base = tvp.bases.default;
      deps = {
        inherit (tvp.packages)
          bash
          coreutils
          gnutar
          xz
          ;
        binutils = tvp.packages.binutils_2;
        meson = tvp.packages.meson;
        ninja = tvp.packages.ninja;
        python = tvp.packages.python-build_3;
        pkg-config = tvp.packages.pkg-config;
        gperf = tvp.packages.gperf;
        freetype =
          tvpLib.packages.withConstraint
            {
              category = "construction";
              reason = "Retained freetype counterpart preserves the complete pre-migration fontconfig profile and public variant identities.";
            }
            (
              (tvpLib.packages.mkVersions
                (import ../freetype { inherit pkgs tvp; }).recipes.freetype.constructionRecipe
              ).freetype_2_15_0
            );
        expat = tvp.packages.expat_2;
        patchelf = tvp.packages.patchelf;
      };
    };
  };
  pname = "fontconfig";
  versionTable = tvpLib.packages.mkTable [
    {
      def = defs."2.18.3";
      releases."2.18.3" = "sha256-T3tVSjjN94wDP2ZsiHHzdJ4UoJT2Wgf2MMke0LQ9NeM=";
    }
  ];
  source =
    { version, sha256 }:
    pkgs.fetchurl {
      url = "https://gitlab.freedesktop.org/api/v4/projects/890/packages/generic/fontconfig/${version}/fontconfig-${version}.tar.xz";
      inherit sha256;
    };
  packageArgs = {
    infra = {
      inherit (pkgs) lib fetchurl;
    };
    inherit pname versionTable source;
    extraArgs.mkTests =
      package:
      import ./tests {
        inherit tvpLib package;
        pkgs = tvpLib.tests.withBase {
          inherit pkgs;
          base.stdenv = package.stdenv;
        };

      }
      // import ./tests/installed.nix {
        inherit package tvpLib;
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
    "2.18.3" = {
      constructor = tvp.builder;
      builder = ./native/build-2.18.3.nix;
      base = candidate.base;
      source =
        { version, sha256 }:
        import <nix/fetchurl.nix> {
          url = "https://gitlab.freedesktop.org/api/v4/projects/890/packages/generic/fontconfig/${version}/fontconfig-${version}.tar.xz";
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
        meson = tvp.packages.meson;
        ninja = tvp.packages.ninja;
        gperf = tvp.packages.gperf;
        pkg-config = tvp.packages.pkg-config;
        freetype = tvp.packages.freetype_2;
        expat = tvp.packages.expat_2;
      };
    };
  };
  publicArgs = packageArgs // {
    versionTable = versionTable // {
      "2.18.3" = versionTable."2.18.3" // {
        def = if native then ownedDefs."2.18.3" else versionTable."2.18.3".def;
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
          // import ./tests/installed.nix {
            inherit package tvpLib;
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
  variants.build-steps = pkgs.lib.optionalAttrs (pkgs.stdenv.hostPlatform.system == "x86_64-linux") {
    fontconfig_2_18_3 = tvp.builder {
      recipe = import ./build-steps-2.18.3.nix;
      args = {
        inherit (pkgs) lib;
        inherit tvp;
        base = tvp.bases.default;
        version = "2.18.3";
        src = source {
          version = "2.18.3";
          inherit (versionTable."2.18.3") sha256;
        };
        inherit (tvp.packages)
          bash
          coreutils
          gnutar
          xz
          ;
      } // defs."2.18.3".deps;
      dependencyNames = [
        "binutils"
        "bash"
        "coreutils"
        "gnutar"
        "xz"
        "meson"
        "ninja"
        "python"
        "pkg-config"
        "gperf"
        "freetype"
        "expat"
        "patchelf"
      ];
      infrastructure = packageArgs.infra;
      metadata = {
        status.level = "ok";
        canonical = false;
        variant = "build-steps";
        builder = "build-steps-2.18.3.nix";
        definition = "2.18.3";
        declaredTestDependencies.python = tvp.packages.python_3;
      };
      selection = {
        namespace = "variants.build-steps";
        selector = "fontconfig_2_18_3";
        kind = "variant";
        pname = "fontconfig";
        version = "2.18.3";
        canonical = "fontconfig_2_18_3";
      };
      mkTests =
        package:
        packageArgs.extraArgs.mkTests package
        // {
          runtime-expectation = import ../../../lib/runtime-expectation.nix { inherit (pkgs) lib; } {
            inherit package;
            stdenv = package.stdenv;
            python = tvp.packages.python_3;
          };
        };
    };
  };
  aliases = tvpLib.packages.mkAliases { inherit pname versionTable canonical; };
}

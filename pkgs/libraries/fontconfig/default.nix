{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  defs = tvpLib.packages.mkDefs {
    "2.18.3" = {
      builder = ./build-2.18.3.nix;
      base = tvp.bases.default;
      deps = {
        meson = tvp.packages.meson;
        ninja = tvp.packages.ninja;
        python = tvp.packages.python-build_3;
        pkg-config = tvp.packages.pkg-config;
        gperf = tvp.packages.gperf;
        freetype = tvp.packages.freetype_2;
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
  canonical = tvpLib.packages.mkVersions packageArgs;
in
{
  inherit canonical;
  variants.build-steps = pkgs.lib.optionalAttrs (pkgs.stdenv.hostPlatform.system == "x86_64-linux") {
    fontconfig_2_18_3 = import ../../../lib/native-recipe.nix { inherit (pkgs) lib; } {
      recipe = import ./build-steps-2.18.3.nix;
      args = {
        inherit (pkgs) lib;
        base = tvp.bases.default;
        version = "2.18.3";
        src = canonical.fontconfig_2_18_3.src;
        inherit (tvp.packages)
          bash
          coreutils
          gnutar
          xz
          ;
      } // defs."2.18.3".deps;
      dependencyNames = [
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
        // import ./tests/installed.nix {
          inherit package tvpLib;
          pkgs = tvpLib.tests.withBase {
            inherit pkgs;
            base.stdenv = package.stdenv;
          };
        }
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

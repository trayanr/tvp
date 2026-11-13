# Retained construction calls and the existing non-native selection fallback.
# Native public releases are defined directly in default.nix.
{
  pkgs,
  tvp,
  packageMeta,
}:
let
  tvpLib = tvp.lib;
  defs = tvpLib.packages.mkDefs {
    "2.4.2" = {
      builder = ./build-2.4.2.nix;
      # trint.c's unprototyped callback requires C99-or-newer, pre-C23
      # semantics. 4.2.1's ChangeLog records its typed C2x-compatible fix.
      opts.checkCFlags = [ "-std=gnu17" ];
      base = tvp.bases.default;
      deps.gmp = tvp.lib.packages.withConstraint {
        reason = "MPFR 2.4.2/3.0.1 public headers use __gmp_const, removed by GMP 5.1. Native compilation fails with newer GMP; 5.0.5 is the working control, selected through the moving 5.0 line.";
      } tvp.packages.gmp_5_0;
      opts.float128 = false;
      opts.mpfrRoundingNames = false;
    };
    "3.0.1" = {
      builder = ./build-2.4.2.nix;
      # trint.c's unprototyped callback requires C99-or-newer, pre-C23
      # semantics. 4.2.1's ChangeLog records its typed C2x-compatible fix.
      opts.checkCFlags = [ "-std=gnu17" ];
      base = tvp.bases.default;
      deps.gmp = tvp.lib.packages.withConstraint {
        reason = "MPFR 2.4.2/3.0.1 public headers use __gmp_const, removed by GMP 5.1. Native compilation fails with newer GMP; 5.0.5 is the working control, selected through the moving 5.0 line.";
      } tvp.packages.gmp_5_0;
      opts.float128 = false;
    };
    "3.1.6" = {
      builder = ./build-2.4.2.nix;
      # trint.c's unprototyped callback requires C99-or-newer, pre-C23
      # semantics. 4.2.1's ChangeLog records its typed C2x-compatible fix.
      opts.checkCFlags = [ "-std=gnu17" ];
      base = tvp.bases.default;
      deps.gmp = tvp.packages.gmp_6;
      opts.float128 = false;
    };
    "4.0.2" = {
      builder = ./build-2.4.2.nix;
      # trint.c's unprototyped callback requires C99-or-newer, pre-C23
      # semantics. 4.2.1's ChangeLog records its typed C2x-compatible fix.
      opts.checkCFlags = [ "-std=gnu17" ];
      base = tvp.bases.default;
      deps.gmp = tvp.packages.gmp_6;
    };
    "4.2.1" = {
      builder = ./build-2.4.2.nix;
      base = tvp.bases.default;
      deps.gmp = tvp.packages.gmp_6;
    };

    "4.2.2" = {
      constructor = tvp.builder;
      builder = ./build-steps-4.2.2.nix;
      base = tvp.bases.default;
      helpers = {
        inherit tvp;
      };
      deps = {
        inherit (tvp.packages)
          bash
          coreutils
          gnumake
          gnutar
          xz
          ;
        gmp = tvp.packages.gmp_6;
        python = tvp.packages.python_3;
        binutils = tvp.packages.binutils_2;
        patchelf = tvp.packages.patchelf_0;
      };
    };
  };
  versionTable = tvpLib.packages.mkTable (import ./releases.nix { inherit defs; });
  pname = "mpfr";
  packageArgs = {
    infra = {
      inherit (pkgs) lib fetchurl;
    };
    inherit pname versionTable packageMeta;
    extraArgs.mkTests = import ./tests/factory.nix { inherit pkgs tvpLib; };
  };
  # Capture the entire legacy call, including its definition, dependencies,
  # options, infrastructure and test factory. Frozen compilers select it explicitly.
  # Preserve the complete old arithmetic factory before public dependency promotion.
  retainedDependencyRecipe = (import ../gmp { inherit pkgs tvp; }).recipes.gmp.constructionRecipe;
  retainedDependency = (tvpLib.packages.mkVersions retainedDependencyRecipe).gmp_5_0_5;
  constructionRecipe = packageArgs // {
    versionTable = versionTable // {
      "2.4.2" = versionTable."2.4.2" // {
        def = defs."2.4.2" // {
          deps = defs."2.4.2".deps // {
            gmp = tvpLib.packages.tagSelection defs."2.4.2".deps.gmp.__tvpSelection retainedDependency;
          };
        };
      };
      "3.0.1" = versionTable."3.0.1" // {
        def = defs."3.0.1" // {
          deps = defs."3.0.1".deps // {
            gmp = tvpLib.packages.tagSelection defs."3.0.1".deps.gmp.__tvpSelection retainedDependency;
          };
        };
      };
      "4.2.2" = versionTable."4.2.2" // {
        def = defs."4.2.1";
      };
    };
  };
in
{
  inherit constructionRecipe;
  publicFallback = packageArgs // {
    source =
      { version, sha256 }:
      pkgs.fetchurl {
        url = "https://mirrors.kernel.org/gnu/mpfr/mpfr-${version}.tar.xz";
        inherit sha256;
      };
  };
}

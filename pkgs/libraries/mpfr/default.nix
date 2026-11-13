{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  native = pkgs.stdenv.hostPlatform.system == "x86_64-linux";
  candidate = import ../../../bases/source-gnu { };
  # Each public definition states its complete inputs and test profile.
  defs = tvpLib.packages.mkDefs {
    "2.4.2" = {
      constructor = tvp.builder;
      builder = ./ordinary/build-2.4.2.nix;
      base = candidate.base;
      source =
        { version, sha256 }:
        import <nix/fetchurl.nix> {
          url = "https://mirrors.kernel.org/gnu/mpfr/mpfr-${version}.tar.xz";
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
        inherit (candidate.tools)
          bash
          coreutils
          xz
          python
          binutils
          patchelf
          sed
          grep
          gawk
          diffutils
          findutils
          ;
        gnumake = candidate.tools.make;
        gnutar = candidate.tools.tar;
        gmp = tvpLib.packages.withConstraint {
          reason = "MPFR 2.4.2/3.0.1 public headers use __gmp_const, removed by GMP 5.1. Native compilation fails with newer GMP; 5.0.5 is the working control, selected through the moving 5.0 line.";
        } tvp.packages.gmp_5_0;
      };
      # Untyped upstream check callbacks need pre-C23 semantics.
      opts = {
        checkCFlags = [ "-std=gnu17" ];
        float128 = false;
        mpfrRoundingNames = false;
      };
      testProfile = "compatibility";
    };
    "3.0.1" = {
      constructor = tvp.builder;
      builder = ./ordinary/build-2.4.2.nix;
      base = candidate.base;
      source =
        { version, sha256 }:
        import <nix/fetchurl.nix> {
          url = "https://mirrors.kernel.org/gnu/mpfr/mpfr-${version}.tar.xz";
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
        inherit (candidate.tools)
          bash
          coreutils
          xz
          python
          binutils
          patchelf
          sed
          grep
          gawk
          diffutils
          findutils
          ;
        gnumake = candidate.tools.make;
        gnutar = candidate.tools.tar;
        gmp = tvpLib.packages.withConstraint {
          reason = "MPFR 2.4.2/3.0.1 public headers use __gmp_const, removed by GMP 5.1. Native compilation fails with newer GMP; 5.0.5 is the working control, selected through the moving 5.0 line.";
        } tvp.packages.gmp_5_0;
      };
      opts = {
        checkCFlags = [ "-std=gnu17" ];
        float128 = false;
      };
      testProfile = "compatibility";
    };
    "3.1.6" = {
      constructor = tvp.builder;
      builder = ./ordinary/build-2.4.2.nix;
      base = candidate.base;
      source =
        { version, sha256 }:
        import <nix/fetchurl.nix> {
          url = "https://mirrors.kernel.org/gnu/mpfr/mpfr-${version}.tar.xz";
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
        inherit (candidate.tools)
          bash
          coreutils
          xz
          python
          binutils
          patchelf
          sed
          grep
          gawk
          diffutils
          findutils
          ;
        gnumake = candidate.tools.make;
        gnutar = candidate.tools.tar;
        gmp = tvp.packages.gmp_6;
      };
      opts = {
        checkCFlags = [ "-std=gnu17" ];
        float128 = false;
      };
      testProfile = "compatibility";
    };
    "4.0.2" = {
      constructor = tvp.builder;
      builder = ./ordinary/build-4.0.2.nix;
      base = candidate.base;
      source =
        { version, sha256 }:
        import <nix/fetchurl.nix> {
          url = "https://mirrors.kernel.org/gnu/mpfr/mpfr-${version}.tar.xz";
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
        inherit (candidate.tools)
          bash
          coreutils
          xz
          python
          binutils
          patchelf
          sed
          grep
          gawk
          diffutils
          findutils
          ;
        gnumake = candidate.tools.make;
        gnutar = candidate.tools.tar;
        gmp = tvp.packages.gmp_6;
      };
      testProfile = "installed";
    };
    "4.2.1" = {
      constructor = tvp.builder;
      builder = ./ordinary/build-4.2.1.nix;
      base = candidate.base;
      source =
        { version, sha256 }:
        import <nix/fetchurl.nix> {
          url = "https://mirrors.kernel.org/gnu/mpfr/mpfr-${version}.tar.xz";
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
        inherit (candidate.tools)
          bash
          coreutils
          xz
          python
          binutils
          patchelf
          sed
          grep
          gawk
          diffutils
          findutils
          ;
        gnumake = candidate.tools.make;
        gnutar = candidate.tools.tar;
        gmp = tvp.packages.gmp_6;
      };
      testProfile = "installed";
    };
    "4.2.2" = {
      constructor = tvp.builder;
      builder = ./build-4.2.2.nix;
      base = candidate.base;
      source =
        { version, sha256 }:
        import <nix/fetchurl.nix> {
          url = "https://mirrors.kernel.org/gnu/mpfr/mpfr-${version}.tar.xz";
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
        inherit (candidate.tools)
          bash
          coreutils
          xz
          python
          binutils
          patchelf
          sed
          grep
          gawk
          diffutils
          findutils
          ;
        gnumake = candidate.tools.make;
        gnutar = candidate.tools.tar;
        gmp = tvp.packages.gmp_6;
      };
      testProfile = "installed";
    };
  };
  versionTable = tvpLib.packages.mkTable (import ./releases.nix { inherit defs; });
  packageMeta.upstream = {
    type = "directory-index";
    url = "https://mirrors.kernel.org/gnu/mpfr/";
    pattern = "mpfr-[0-9][^\"]*\\.tar\\.(gz|bz2|xz)";
    normalise =
      file:
      let
        match = builtins.match "mpfr-([0-9]+(\\.[0-9]+)*)\\.tar\\.(gz|bz2|xz)" file;
      in
      if match == null then null else builtins.head match;
    include = version: builtins.match "[0-9]+(\\.[0-9]+)*" version != null;
  };
  retained = import ./retained.nix { inherit pkgs tvp packageMeta; };
  installedTests = import ./tests/factory.nix { inherit pkgs tvpLib; };
  publicArgs = {
    pname = "mpfr";
    infra = {
      inherit (pkgs) lib fetchurl;
    };
    inherit versionTable packageMeta;
    # Preserve the published family source factory; native definitions select
    # their own explicit source factory above.
    source = retained.publicFallback.source;
    extraArgs.mkTests = pkgs.lib.makeOverridable (
      { pkgs }:
      package:
      let
        suite = (installedTests.override { inherit pkgs; }) package;
        # A caller may override version without changing definition metadata.
        profile = versionTable.${package.version}.def.testProfile or "installed";
      in
      suite
      //
        pkgs.lib.optionalAttrs
          (
            package ? testContext
            && profile == "compatibility"
            && (package.specification.upstreamCheck.enabled or true)
          )
          {
            upstream = import ../acl/native/upstream.nix { inherit package; };
          }
    ) { inherit pkgs; };
  };
  selected =
    if native then publicArgs else retained.publicFallback // { extraArgs = publicArgs.extraArgs; };
  canonical = tvpLib.packages.mkVersions selected;
in
{
  recipes.mpfr = selected // {
    inherit (retained) constructionRecipe;
  };
  inherit canonical;
  variants.build-steps = import ./variants.nix {
    inherit pkgs tvp;
    family = retained.publicFallback;
  };
  aliases = tvpLib.packages.mkAliases {
    pname = "mpfr";
    versionTable = selected.versionTable;
    inherit canonical;
  };
}

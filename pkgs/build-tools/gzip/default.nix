{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  previous = import ./legacy.nix { inherit pkgs tvp; };
  constructionRecipe = previous.recipes.gzip;
  candidate = import ../../../bases/source-gnu { };
  native = pkgs.stdenv.hostPlatform.system == "x86_64-linux";
  host =
    name: reason:
    tvpLib.packages.withConstraint {
      category = "construction";
      inherit reason;
    } candidate.tools.${name};
  defs = tvpLib.packages.mkDefs {
    "1.15" = {
      constructor = tvp.builder;
      builder = ./native/build-1.15.nix;
      base = candidate.base;
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
        bash = tvp.packages.bash_5;
        coreutils = tvp.packages.coreutils_9;
        gnumake = tvp.packages.gnumake_4;
        gnutar = tvp.packages.gnutar_1;
        xz = tvp.packages.xz_5;
        findutils = tvp.packages.findutils_4;
        sed = tvp.packages.gnused_4;
        grep = tvp.packages.gnugrep_3;
        gawk = tvpLib.packages.withConstraint {
          reason = "Gzip is used by MPFR build prerequisites; Gawk 5 depends on MPFR. Keep the build-only AWK input on the MPFR-free Gawk 4.0 line.";
        } tvp.packages.gawk_4_0;
        diffutils = tvp.packages.diffutils_3;
        python = host "python" "Independent source/output helper avoids catalogue dependency cycles.";
        binutils = host "linker" "Owned ELF output tools independent of catalogue consumers.";
        patchelf = host "patchelf" "Owned RPATH tool independent of catalogue consumers.";
        pager = tvp.packages.less;
      };
    };
    "1.13" = {
      constructor = tvp.builder;
      builder = ./ordinary/build-1.13.nix;
      base = candidate.base;
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
        bash = tvp.packages.bash_5;
        coreutils = tvp.packages.coreutils_9;
        gnumake = tvp.packages.gnumake_4;
        gnutar = tvp.packages.gnutar_1;
        xz = tvp.packages.xz_5;
        findutils = tvp.packages.findutils_4;
        sed = tvp.packages.gnused_4;
        grep = tvp.packages.gnugrep_3;
        gawk = tvp.packages.gawk_5;
        diffutils = tvp.packages.diffutils_3;
        python = host "python" "Independent source/output helper avoids catalogue dependency cycles.";
        binutils = host "linker" "Owned ELF output tools independent of catalogue consumers.";
        patchelf = host "patchelf" "Owned RPATH tool independent of catalogue consumers.";
        pager = tvp.packages.less;
      };
    };
  };
  versionTable = previous.recipes.gzip.versionTable // {
    "1.15" = previous.recipes.gzip.versionTable."1.15" // {
      def = if native then defs."1.15" else previous.recipes.gzip.versionTable."1.15".def;
    };
    "1.13" = previous.recipes.gzip.versionTable."1.13" // {
      def = if native then defs."1.13" else previous.recipes.gzip.versionTable."1.13".def;
    };
    "1.14" = previous.recipes.gzip.versionTable."1.14" // {
      def = if native then defs."1.13" else previous.recipes.gzip.versionTable."1.14".def;
    };
  };

  installedArgs = previous.recipes.gzip // {
    inherit versionTable;
    source =
      { version, sha256 }:
      pkgs.fetchurl {
        url = "https://mirrors.kernel.org/gnu/gzip/gzip-${version}.tar.xz";
        inherit sha256;
      };
    testDeps = {
      sentinel = (import ../../../bases/source-gnu/tests/probes.nix { }).sentinel;
      alternateSource = (import ../../../bootstrap/source-cmake-prerequisite-tests.nix { }).alternate;
      sourceGzip = candidate.tools.gzip;
    };
    extraArgs.mkTests = pkgs.lib.makeOverridable (
      { pkgs }:
      package:
      if package ? testContext then
        import
          (
            if
              builtins.elem package.version [
                "1.13"
                "1.14"
              ]
            then
              ./tests/ordinary.nix
            else
              ./tests/native-default.nix
          )
          {
            inherit
              pkgs
              tvp
              tvpLib
              package
              ;
          }
      else
        import ./tests {
          inherit pkgs tvpLib package;
          coreutils = tvp.packages.coreutils;
        }
    ) { inherit pkgs; };
  };
  publicArgs = installedArgs // {
    extraArgs = installedArgs.extraArgs // {
      mkTests = pkgs.lib.makeOverridable (
        { pkgs }:
        package:
        (
          if installedArgs.extraArgs.mkTests ? override then
            (installedArgs.extraArgs.mkTests.override { inherit pkgs; }) package
          else
            installedArgs.extraArgs.mkTests package
        )
        // (import ../owned-split-tests.nix { inherit pkgs tvp package; })
      ) { inherit pkgs; };
    };
  };
  canonical = tvpLib.packages.mkVersions publicArgs;
  pname = "gzip";
in
{
  recipes.${pname} = publicArgs // {
    inherit constructionRecipe;
  };
  inherit canonical;
  aliases = tvpLib.packages.mkAliases { inherit pname versionTable canonical; };
}

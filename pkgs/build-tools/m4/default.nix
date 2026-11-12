{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  # Complete former definitions, sources, arguments and test factories. Frozen
  # construction consumers retain their original route, including Make's 4.3 map.
  previous = import ./legacy.nix { inherit pkgs tvp; };
  ownedDefaultRecipe = removeAttrs previous.recipes.m4 [ "constructionRecipe" ];
  constructionRecipe = previous.recipes.m4.constructionRecipe;
  candidate = import ../../../bases/source-gnu { };
  native = pkgs.stdenv.hostPlatform.system == "x86_64-linux";
  host =
    name: reason:
    tvpLib.packages.withConstraint {
      category = "construction";
      inherit reason;
    } candidate.tools.${name};
  defs = tvpLib.packages.mkDefs {
    "1.4.21" = {
      constructor = tvp.builder;
      builder = ./native/build-1.4.21.nix;
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
        coreutils = host "coreutils" "Independent host Coreutils avoids Coreutils -> GMP -> M4 while constructing this tool.";
        gnumake = tvp.packages.gnumake_4;
        gnutar = tvp.packages.gnutar_1;
        gzip = tvp.packages.gzip_1;
        findutils = host "findutils" "Independent source unpack/epoch inventory tool.";
        python = host "python" "Independent source and output helper interpreter; no public Python prerequisite cycle.";
        binutils = host "binutils" "Independent output inspector avoids Binutils -> Bison -> M4.";
        patchelf = host "patchelf" "Independent finalizer avoids Patchelf -> ordinary Make -> Patchelf.";
        sed = tvp.packages.gnused_4;
        grep = tvp.packages.gnugrep_3;
        gawk = tvp.packages.gawk_5;
        diffutils = tvp.packages.diffutils_3;
      };
    };
    "1.4.19" = {
      constructor = tvp.builder;
      builder = ./ordinary/build-1.4.19.nix;
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
      opts.cStandard = "gnu17";
      deps = {
        bash = tvp.packages.bash_5;
        coreutils = host "coreutils" "Independent host Coreutils avoids Coreutils -> GMP -> M4 while constructing this tool.";
        gnumake = tvp.packages.gnumake_4;
        gnutar = tvp.packages.gnutar_1;
        gzip = tvp.packages.gzip_1;
        findutils = host "findutils" "Independent source unpack/epoch inventory tool.";
        python = host "python" "Independent source and output helper interpreter; no public Python prerequisite cycle.";
        binutils = host "binutils" "Independent output inspector avoids Binutils -> Bison -> M4.";
        patchelf = host "patchelf" "Independent finalizer avoids Patchelf -> ordinary Make -> Patchelf.";
        sed = tvp.packages.gnused_4;
        grep = tvp.packages.gnugrep_3;
        gawk = tvp.packages.gawk_5;
        diffutils = tvp.packages.diffutils_3;
      };
    };
    "1.4.20" = {
      constructor = tvp.builder;
      builder = ./ordinary/build-1.4.20.nix;
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
        coreutils = host "coreutils" "Independent host Coreutils avoids Coreutils -> GMP -> M4 while constructing this tool.";
        gnumake = tvp.packages.gnumake_4;
        gnutar = tvp.packages.gnutar_1;
        gzip = tvp.packages.gzip_1;
        findutils = host "findutils" "Independent source unpack/epoch inventory tool.";
        python = host "python" "Independent source and output helper interpreter; no public Python prerequisite cycle.";
        binutils = host "binutils" "Independent output inspector avoids Binutils -> Bison -> M4.";
        patchelf = host "patchelf" "Independent finalizer avoids Patchelf -> ordinary Make -> Patchelf.";
        sed = tvp.packages.gnused_4;
        grep = tvp.packages.gnugrep_3;
        gawk = tvp.packages.gawk_5;
        diffutils = tvp.packages.diffutils_3;
      };
    };
  };
  versionTable = ownedDefaultRecipe.versionTable // {
    "1.4.21" = ownedDefaultRecipe.versionTable."1.4.21" // {
      def = if native then defs."1.4.21" else ownedDefaultRecipe.versionTable."1.4.21".def;
    };
    "1.4.19" = ownedDefaultRecipe.versionTable."1.4.19" // {
      def = if native then defs."1.4.19" else ownedDefaultRecipe.versionTable."1.4.19".def;
    };
    "1.4.20" = ownedDefaultRecipe.versionTable."1.4.20" // {
      def = if native then defs."1.4.20" else ownedDefaultRecipe.versionTable."1.4.20".def;
    };
  };

  installedArgs = ownedDefaultRecipe // {
    inherit versionTable;
    testDeps = {
      grep = tvp.packages.gnugrep_3;
      gawk = tvp.packages.gawk_5;
      gnumake = tvp.packages.gnumake_4;
      compiler = candidate.toolchain.driver;
      pkgConfig = tvp.packages.pkg-config;
      mpfr = tvp.packages.mpfr;
      runtimeShell = candidate.tools.bash;
      coreutils = candidate.tools.coreutils;
      alternateCoreutils = tvp.packages.coreutils;
      python = candidate.tools.python;
      binutils = candidate.tools.binutils;
      sentinel = (import ../../../bases/source-gnu/tests/probes.nix { }).sentinel;
      alternateSource = (import ../../../bootstrap/source-cmake-prerequisite-tests.nix { }).alternate;
    };
    extraArgs.mkTests = pkgs.lib.makeOverridable (
      { pkgs }:
      package:
      if package ? testContext then
        import
          (
            if
              builtins.elem package.version [
                "1.4.19"
                "1.4.20"
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
        ownedDefaultRecipe.extraArgs.mkTests package
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
  pname = "m4";
in
{
  recipes.${pname} = publicArgs // {
    inherit constructionRecipe ownedDefaultRecipe;
  };
  inherit canonical;
  aliases = tvpLib.packages.mkAliases { inherit pname versionTable canonical; };
}

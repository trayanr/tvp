{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  # Complete former definitions, sources, arguments and test factories. Frozen
  # construction consumers retain their original route, including Make's 4.3 map.
  previous = import ./legacy.nix { inherit pkgs tvp; };
  ownedDefaultRecipe = removeAttrs previous.recipes.gnumake [ "constructionRecipe" ];
  constructionRecipe = previous.recipes.gnumake.constructionRecipe;
  candidate = import ../../../bases/source-gnu { };
  native = pkgs.stdenv.hostPlatform.system == "x86_64-linux";
  host =
    name: reason:
    tvpLib.packages.withConstraint {
      category = "construction";
      inherit reason;
    } candidate.tools.${name};
  defs = tvpLib.packages.mkDefs {
    "4.4.1" = {
      constructor = tvp.builder;
      builder = ./native/build-4.4.1.nix;
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
        gnumake = host "make" "Make must build with an independent retained host Make, never its canonical self.";
        gnutar = host "tar" "Independent candidate tar is a build-only construction tool for foundational Make; it keeps this procedure separate from ordinary catalogue consumers.";
        gzip = host "gzip" "Independent candidate gzip is a build-only construction tool for foundational Make; it keeps this procedure separate from ordinary catalogue consumers.";
        findutils = host "findutils" "Independent source unpack/epoch inventory tool.";
        python = host "python" "Independent source and output helper interpreter; no public Python prerequisite cycle.";
        binutils = host "binutils" "Independent output inspector avoids Binutils -> Bison -> M4.";
        patchelf = host "patchelf" "Independent finalizer avoids Patchelf -> ordinary Make -> Patchelf.";
        sed = host "sed" "Independent candidate sed is a build-only construction tool for foundational Make; it keeps this procedure separate from ordinary catalogue consumers.";
        grep = host "grep" "Independent candidate grep is a build-only construction tool for foundational Make; it keeps this procedure separate from ordinary catalogue consumers.";
        gawk = host "gawk" "Independent candidate gawk is a build-only construction tool for foundational Make; it keeps this procedure separate from ordinary catalogue consumers.";
        diffutils = host "diffutils" "Independent candidate diffutils is a build-only construction tool for foundational Make; it keeps this procedure separate from ordinary catalogue consumers.";
        perl = host "perl" "Independent Perl executes the complete shipped Make test harness.";
      };
    };
  };
  versionTable = ownedDefaultRecipe.versionTable // {
    "4.4.1" = ownedDefaultRecipe.versionTable."4.4.1" // {
      def = if native then defs."4.4.1" else ownedDefaultRecipe.versionTable."4.4.1".def;
    };
  };
  publicArgs = ownedDefaultRecipe // {
    inherit versionTable;
    testDeps = {
      grep = host "grep" "Native Make assertions use the same independent grep provider as its procedure.";
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
        import ./tests/native-default.nix {
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
  canonical = tvpLib.packages.mkVersions publicArgs;
  pname = "gnumake";
in
{
  recipes.${pname} = publicArgs // {
    inherit constructionRecipe ownedDefaultRecipe;
  };
  inherit canonical;
  aliases = tvpLib.packages.mkAliases { inherit pname versionTable canonical; };
}

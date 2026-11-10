{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  previous = import ./legacy.nix { inherit pkgs tvp; };
  constructionRecipe = previous.recipes.automake;
  candidate = import ../../../bases/source-gnu { };
  native = pkgs.stdenv.hostPlatform.system == "x86_64-linux";
  host =
    name: reason:
    tvpLib.packages.withConstraint {
      category = "construction";
      inherit reason;
    } candidate.tools.${name};
  defs = tvpLib.packages.mkDefs {
    "1.12" = {
      constructor = tvp.builder;
      builder = ./ordinary/build-1.12.nix;
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
        autoconf = tvp.packages.autoconf_2;
        perl = tvp.packages.perl_5;
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
        python = host "python" "Independent source/output helper avoids public Python -> pkg-config -> Autoconf.";
      };
    };
    "1.19" = {
      constructor = tvp.builder;
      builder = ./native/build-1.19.nix;
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
        autoconf = tvp.packages.autoconf_2;
        perl = tvp.packages.perl_5;
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
        python = host "python" "Independent source/output helper avoids public Python -> pkg-config -> Autoconf.";
      };
    };
  };
  versionTable = constructionRecipe.versionTable // {
    "1.12" = constructionRecipe.versionTable."1.12" // {
      def = if native then defs."1.12" else constructionRecipe.versionTable."1.12".def;
    };
    "1.12.1" = constructionRecipe.versionTable."1.12.1" // {
      def = if native then defs."1.12" else constructionRecipe.versionTable."1.12.1".def;
    };
    "1.12.2" = constructionRecipe.versionTable."1.12.2" // {
      def = if native then defs."1.12" else constructionRecipe.versionTable."1.12.2".def;
    };
    "1.12.3" = constructionRecipe.versionTable."1.12.3" // {
      def = if native then defs."1.12" else constructionRecipe.versionTable."1.12.3".def;
    };
    "1.12.4" = constructionRecipe.versionTable."1.12.4" // {
      def = if native then defs."1.12" else constructionRecipe.versionTable."1.12.4".def;
    };
    "1.12.5" = constructionRecipe.versionTable."1.12.5" // {
      def = if native then defs."1.12" else constructionRecipe.versionTable."1.12.5".def;
    };
    "1.12.6" = constructionRecipe.versionTable."1.12.6" // {
      def = if native then defs."1.12" else constructionRecipe.versionTable."1.12.6".def;
    };
    "1.13" = constructionRecipe.versionTable."1.13" // {
      def = if native then defs."1.12" else constructionRecipe.versionTable."1.13".def;
    };
    "1.13.1" = constructionRecipe.versionTable."1.13.1" // {
      def = if native then defs."1.12" else constructionRecipe.versionTable."1.13.1".def;
    };
    "1.13.2" = constructionRecipe.versionTable."1.13.2" // {
      def = if native then defs."1.12" else constructionRecipe.versionTable."1.13.2".def;
    };
    "1.13.3" = constructionRecipe.versionTable."1.13.3" // {
      def = if native then defs."1.12" else constructionRecipe.versionTable."1.13.3".def;
    };
    "1.13.4" = constructionRecipe.versionTable."1.13.4" // {
      def = if native then defs."1.12" else constructionRecipe.versionTable."1.13.4".def;
    };
    "1.14" = constructionRecipe.versionTable."1.14" // {
      def = if native then defs."1.12" else constructionRecipe.versionTable."1.14".def;
    };
    "1.14.1" = constructionRecipe.versionTable."1.14.1" // {
      def = if native then defs."1.12" else constructionRecipe.versionTable."1.14.1".def;
    };
    "1.15" = constructionRecipe.versionTable."1.15" // {
      def = if native then defs."1.12" else constructionRecipe.versionTable."1.15".def;
    };
    "1.15.1" = constructionRecipe.versionTable."1.15.1" // {
      def = if native then defs."1.12" else constructionRecipe.versionTable."1.15.1".def;
    };
    "1.16" = constructionRecipe.versionTable."1.16" // {
      def = if native then defs."1.12" else constructionRecipe.versionTable."1.16".def;
    };
    "1.16.1" = constructionRecipe.versionTable."1.16.1" // {
      def = if native then defs."1.12" else constructionRecipe.versionTable."1.16.1".def;
    };
    "1.16.2" = constructionRecipe.versionTable."1.16.2" // {
      def = if native then defs."1.12" else constructionRecipe.versionTable."1.16.2".def;
    };
    "1.16.3" = constructionRecipe.versionTable."1.16.3" // {
      def = if native then defs."1.12" else constructionRecipe.versionTable."1.16.3".def;
    };
    "1.16.4" = constructionRecipe.versionTable."1.16.4" // {
      def = if native then defs."1.12" else constructionRecipe.versionTable."1.16.4".def;
    };
    "1.16.5" = constructionRecipe.versionTable."1.16.5" // {
      def = if native then defs."1.12" else constructionRecipe.versionTable."1.16.5".def;
    };
    "1.17" = constructionRecipe.versionTable."1.17" // {
      def = if native then defs."1.12" else constructionRecipe.versionTable."1.17".def;
    };
    "1.18" = constructionRecipe.versionTable."1.18" // {
      def = if native then defs."1.12" else constructionRecipe.versionTable."1.18".def;
    };
    "1.18.1" = constructionRecipe.versionTable."1.18.1" // {
      def = if native then defs."1.12" else constructionRecipe.versionTable."1.18.1".def;
    };

    "1.19" = constructionRecipe.versionTable."1.19" // {
      def = if native then defs."1.19" else constructionRecipe.versionTable."1.19".def;
    };
  };
  publicArgs = constructionRecipe // {
    inherit versionTable;
    source =
      { version, sha256 }:
      pkgs.fetchurl {
        urls = [
          "https://mirrors.kernel.org/gnu/automake/automake-${version}.tar.xz"
          "https://ftp.gnu.org/gnu/automake/automake-${version}.tar.xz"
        ];
        inherit sha256;
      };
    testDeps = {

      libtool = tvp.packages.libtool_2;
      alternatePerl = candidate.tools.perl;
      alternateM4 = candidate.tools.m4;
      runtimeShell = candidate.tools.bash;
      python = candidate.tools.python;
      sentinel = (import ../../../bases/source-gnu/tests/probes.nix { }).sentinel;
      alternateSource = (import ../../../bootstrap/source-cmake-prerequisite-tests.nix { }).alternate;
    };
    extraArgs.mkTests = pkgs.lib.makeOverridable (
      { pkgs }:
      package:
      if package ? testContext then
        import
          (
            if (package.tvp.ordinaryAutotools or false) then
              ./tests/ordinary-default.nix
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
        constructionRecipe.extraArgs.mkTests.override { inherit pkgs; } package
    ) { inherit pkgs; };
  };
  canonical = tvpLib.packages.mkVersions publicArgs;
  pname = "automake";
in
{
  recipes.${pname} = publicArgs // {
    inherit constructionRecipe;
  };
  inherit canonical;
  aliases = tvpLib.packages.mkAliases { inherit pname versionTable canonical; };
}

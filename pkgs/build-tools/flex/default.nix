{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  previous = import ./legacy.nix { inherit pkgs tvp; };
  constructionRecipe = previous.recipes.flex;
  candidate = import ../../../bases/source-gnu { };
  native = pkgs.stdenv.hostPlatform.system == "x86_64-linux";
  host =
    name: reason:
    tvpLib.packages.withConstraint {
      category = "construction";
      inherit reason;
    } candidate.tools.${name};
  defs = tvpLib.packages.mkDefs {
    "2.6.4" = {
      constructor = tvp.builder;
      builder = ./native/build-2.6.4.nix;
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
        m4 = tvp.packages.m4_1;
        file = tvp.packages.file_5;
        bash = tvp.packages.bash_5;
        coreutils = tvp.packages.coreutils_9;
        gnumake = tvp.packages.gnumake_4;
        gnutar = tvp.packages.gnutar_1;
        gzip = tvp.packages.gzip_1;
        findutils = tvp.packages.findutils_4;
        sed = tvp.packages.gnused_4;
        grep = tvp.packages.gnugrep_3;
        gawk = tvp.packages.gawk_5;
        diffutils = tvp.packages.diffutils_3;
        python = host "python" "Independent source/output helper avoids public Python -> pkg-config -> Autoconf.";
        binutils = host "linker" "Owned ELF output tools selected independently of catalogue consumers.";
        patchelf = host "patchelf" "Owned RPATH tool independent of catalogue consumers.";
      };
    };
    "2.6.1" = {
      constructor = tvp.builder;
      builder = ./ordinary/build-2.6.1.nix;
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
      patches = [
        {
          file = ./patches/2.6.2-null-restart.patch;
          reason = "Avoid a null C++ istream reference in yyrestart(NULL), also present before the upstream restart test was added.";
        }
      ];
      deps = {
        patch = candidate.tools.patch;
        m4 = tvp.packages.m4_1;
        bison = tvp.packages.bison;
        file = tvp.packages.file_5;
        bash = tvp.packages.bash_5;
        coreutils = tvp.packages.coreutils_9;
        gnumake = tvp.packages.gnumake_4;
        gnutar = tvp.packages.gnutar_1;
        gzip = tvp.packages.gzip_1;
        findutils = tvp.packages.findutils_4;
        sed = tvp.packages.gnused_4;
        grep = tvp.packages.gnugrep_3;
        gawk = tvp.packages.gawk_5;
        diffutils = tvp.packages.diffutils_3;
        python = host "python" "Independent source/output helper avoids public Python -> pkg-config -> Autoconf.";
        binutils = host "linker" "Owned ELF output tools selected independently of catalogue consumers.";
        patchelf = host "patchelf" "Owned RPATH tool independent of catalogue consumers.";
      };
    };
    "2.6.2" = {
      constructor = tvp.builder;
      builder = ./ordinary/build-2.6.2.nix;
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
      patches = [
        {
          file = ./patches/2.6.2-null-restart.patch;
          reason = "Avoid forming a null C++ istream reference in yyrestart(NULL); preserve its null stream-buffer semantics and run the original cxx_restart assertion.";
        }

        {
          file = ./patches/2.6.2-manpage-prerequisites.patch;
          reason = "Backport shipped man-page prerequisite rule from 2.6.3.";
        }
      ];
      deps = {
        patch = candidate.tools.patch;
        m4 = tvp.packages.m4_1;
        bison = tvp.packages.bison;
        file = tvp.packages.file_5;
        bash = tvp.packages.bash_5;
        coreutils = tvp.packages.coreutils_9;
        gnumake = tvp.packages.gnumake_4;
        gnutar = tvp.packages.gnutar_1;
        gzip = tvp.packages.gzip_1;
        findutils = tvp.packages.findutils_4;
        sed = tvp.packages.gnused_4;
        grep = tvp.packages.gnugrep_3;
        gawk = tvp.packages.gawk_5;
        diffutils = tvp.packages.diffutils_3;
        python = host "python" "Independent source/output helper avoids public Python -> pkg-config -> Autoconf.";
        binutils = host "linker" "Owned ELF output tools selected independently of catalogue consumers.";
        patchelf = host "patchelf" "Owned RPATH tool independent of catalogue consumers.";
      };
    };
    "2.6.3" = {
      constructor = tvp.builder;
      builder = ./ordinary/build-2.6.2.nix;
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
      patches = [
        {
          file = ./patches/2.6.2-null-restart.patch;
          reason = "Avoid forming a null C++ istream reference in yyrestart(NULL); preserve its null stream-buffer semantics and run the original cxx_restart assertion.";
        }
      ];
      deps = {
        patch = candidate.tools.patch;
        m4 = tvp.packages.m4_1;
        bison = tvp.packages.bison;
        file = tvp.packages.file_5;
        bash = tvp.packages.bash_5;
        coreutils = tvp.packages.coreutils_9;
        gnumake = tvp.packages.gnumake_4;
        gnutar = tvp.packages.gnutar_1;
        gzip = tvp.packages.gzip_1;
        findutils = tvp.packages.findutils_4;
        sed = tvp.packages.gnused_4;
        grep = tvp.packages.gnugrep_3;
        gawk = tvp.packages.gawk_5;
        diffutils = tvp.packages.diffutils_3;
        python = host "python" "Independent source/output helper avoids public Python -> pkg-config -> Autoconf.";
        binutils = host "linker" "Owned ELF output tools selected independently of catalogue consumers.";
        patchelf = host "patchelf" "Owned RPATH tool independent of catalogue consumers.";
      };
    };
  };
  versionTable = constructionRecipe.versionTable // {
    "2.6.4" = constructionRecipe.versionTable."2.6.4" // {
      def = if native then defs."2.6.4" else constructionRecipe.versionTable."2.6.4".def;
    };
    "2.6.1" = constructionRecipe.versionTable."2.6.1" // {
      def = if native then defs."2.6.1" else constructionRecipe.versionTable."2.6.1".def;
    };
    "2.6.2" = constructionRecipe.versionTable."2.6.2" // {
      def = if native then defs."2.6.2" else constructionRecipe.versionTable."2.6.2".def;
    };
    "2.6.3" = constructionRecipe.versionTable."2.6.3" // {
      def = if native then defs."2.6.3" else constructionRecipe.versionTable."2.6.3".def;
    };
  };

  installedArgs = constructionRecipe // {
    inherit versionTable;
    source =
      { version, sha256 }:
      pkgs.fetchurl {
        url = "https://github.com/westes/flex/releases/download/v${version}/flex-${version}.tar.gz";
        inherit sha256;
      };
    testDeps = {
      sentinel = (import ../../../bases/source-gnu/tests/probes.nix { }).sentinel;
      alternateSource = (import ../../../bootstrap/source-cmake-prerequisite-tests.nix { }).alternate;
      bison = tvp.packages.bison;
    };
    extraArgs.mkTests =
      pkgs.lib.makeOverridable
        (
          { pkgs }:
          package:
          if package ? testContext then
            import
              (
                if
                  builtins.elem package.version [
                    "2.6.1"
                    "2.6.2"
                    "2.6.3"
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
            (constructionRecipe.extraArgs.mkTests.override { inherit pkgs; }) package
        )
        {
          pkgs = tvpLib.tests.withBase {
            inherit pkgs;
            base = tvp.bases.default;
          };
        };
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
  pname = "flex";
in
{
  recipes.${pname} = publicArgs // {
    inherit constructionRecipe;
  };
  inherit canonical;
  aliases = tvpLib.packages.mkAliases { inherit pname versionTable canonical; };
}

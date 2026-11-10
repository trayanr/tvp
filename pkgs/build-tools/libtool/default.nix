{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  previous = import ./legacy.nix { inherit pkgs tvp; };
  constructionRecipe = previous.recipes.libtool;
  candidate = import ../../../bases/source-gnu { };
  native = pkgs.stdenv.hostPlatform.system == "x86_64-linux";
  host =
    name: reason:
    tvpLib.packages.withConstraint {
      category = "construction";
      inherit reason;
    } candidate.tools.${name};
  defs = tvpLib.packages.mkDefs {
    "2.2.10" = {
      constructor = tvp.builder;
      builder = ./ordinary/build-2.2.10.nix;
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
        automake = tvp.packages.automake_1;
        m4 = tvp.packages.m4_1;
        file = tvp.packages.file_5;
        patch = tvp.packages.patch_2;
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
        patchelf = host "patchelf" "Owned output RPATH tool independent of catalogue consumers.";
      };
    };
    "2.4.7" = {
      constructor = tvp.builder;
      builder = ./ordinary/build-2.4.7.nix;
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
        automake = tvp.packages.automake_1;
        m4 = tvp.packages.m4_1;
        file = tvp.packages.file_5;
        patch = tvp.packages.patch_2;
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
        binutils = host "linker" "Owned ELF output tools selected independently of catalogue consumers.";
        patchelf = host "patchelf" "Owned output RPATH tool independent of catalogue consumers.";
      };
      patches = [
        {
          file = ./patches/declared-tools.patch;
          reason = "Store-layout adaptation: declared Autoconf/Automake defaults preserve user overrides.";
        }
      ];
    };
    "2.6.2" = {
      constructor = tvp.builder;
      builder = ./native/build-2.6.2.nix;
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
        automake = tvp.packages.automake_1;
        m4 = tvp.packages.m4_1;
        file = tvp.packages.file_5;
        patch = tvp.packages.patch_2;
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
        binutils = host "linker" "Owned ELF output tools selected independently of catalogue consumers.";
        patchelf = host "patchelf" "Owned output RPATH tool independent of catalogue consumers.";
      };
      patches = [
        {
          file = ./patches/declared-tools.patch;
          reason = "Store-layout adaptation: declared Autoconf/Automake defaults preserve user overrides.";
        }
      ];
    };
  };
  versionTable = constructionRecipe.versionTable // {
    "2.2.10" = constructionRecipe.versionTable."2.2.10" // {
      def = if native then defs."2.2.10" else constructionRecipe.versionTable."2.2.10".def;
    };
    "2.4.7" = constructionRecipe.versionTable."2.4.7" // {
      def = if native then defs."2.4.7" else constructionRecipe.versionTable."2.4.7".def;
    };
    "2.5.3" = constructionRecipe.versionTable."2.5.3" // {
      def = if native then defs."2.4.7" else constructionRecipe.versionTable."2.5.3".def;
    };
    "2.5.4" = constructionRecipe.versionTable."2.5.4" // {
      def = if native then defs."2.4.7" else constructionRecipe.versionTable."2.5.4".def;
    };

    "2.6.2" = constructionRecipe.versionTable."2.6.2" // {
      def = if native then defs."2.6.2" else constructionRecipe.versionTable."2.6.2".def;
    };
  };
  publicArgs = constructionRecipe // {
    inherit versionTable;
    source =
      { version, sha256 }:
      pkgs.fetchurl {
        urls = [
          "https://mirrors.kernel.org/gnu/libtool/libtool-${version}.${
            if version == "2.2.10" then "tar.gz" else "tar.xz"
          }"
        ];
        inherit sha256;
      };
    testDeps = {
      runtimeShell = candidate.tools.bash;
      gzip = tvp.packages.gzip_1;
      python = candidate.tools.python;
      sentinel = (import ../../../bases/source-gnu/tests/probes.nix { }).sentinel;
      alternateSource = (import ../../../bootstrap/source-cmake-prerequisite-tests.nix { }).alternate;

    };
    extraArgs.mkTests =
      pkgs.lib.makeOverridable
        (
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
        )
        {
          pkgs = tvpLib.tests.withBase {
            inherit pkgs;
            base = tvp.bases.default;
          };
        };
  };
  canonical = tvpLib.packages.mkVersions publicArgs;
  pname = "libtool";
in
{
  recipes.${pname} = publicArgs // {
    inherit constructionRecipe;
  };
  inherit canonical;
  aliases = tvpLib.packages.mkAliases { inherit pname versionTable canonical; };
}

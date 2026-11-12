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
    "1.0" = {
      constructor = tvp.builder;
      builder = ./ordinary/build-1.0.nix;
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
        platformAutomake = tvp.packages.automake_1;
        automake = (
          tvp.lib.packages.withConstraint {
            reason = "Libtool 1.0 cannot parse Automake 1.5 depcomp's .deps/answer.TPlo library-object argument; current 1.19 also fails on compile -o handling. Native shared/static project passes with Automake 1.4-p6 and fails with 1.5 and 1.19; retain the moving 1.4 line.";
          } tvp.packages.automake_1_4
        );
        m4 = tvp.packages.m4;
        file = tvp.packages.file;
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
      # Shipped configure and ltconfig probes use implicit-int main().
      opts.cStandard = "gnu89";
      opts = {
        testFeatures = {
          acLibtool = false;
          ltdl = false;
        };
        license = pkgs.lib.licenses.gpl2Plus;
      };
    };
    "1.3.5" = {
      constructor = tvp.builder;
      builder = ./ordinary/build-1.3.5.nix;
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
        platformAutomake = tvp.packages.automake_1;
        automake = tvp.packages.automake_1;
        m4 = tvp.packages.m4;
        file = tvp.packages.file;
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
      # Shipped configure and ltconfig probes use implicit-int main().
      opts.cStandard = "gnu89";
    };
    "1.5.26" = {
      constructor = tvp.builder;
      builder = ./ordinary/build-1.5.26.nix;
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
        m4 = tvp.packages.m4;
        file = tvp.packages.file;
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
    "1.0" = constructionRecipe.versionTable."1.0" // {
      def = if native then defs."1.0" else constructionRecipe.versionTable."1.0".def;
    };
    "1.1" = constructionRecipe.versionTable."1.1" // {
      def = if native then defs."1.0" else constructionRecipe.versionTable."1.1".def;
    };
    "1.2" = constructionRecipe.versionTable."1.2" // {
      def = if native then defs."1.0" else constructionRecipe.versionTable."1.2".def;
    };
    "1.3.5" = constructionRecipe.versionTable."1.3.5" // {
      def = if native then defs."1.3.5" else constructionRecipe.versionTable."1.3.5".def;
    };
    "1.4.3" = constructionRecipe.versionTable."1.4.3" // {
      def = if native then defs."1.3.5" else constructionRecipe.versionTable."1.4.3".def;
    };
    "1.5.26" = constructionRecipe.versionTable."1.5.26" // {
      def = if native then defs."1.5.26" else constructionRecipe.versionTable."1.5.26".def;
    };
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
            if pkgs.lib.versionOlder version "2.4.7" then "tar.gz" else "tar.xz"
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

{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  previous = import ./legacy.nix { inherit pkgs tvp; };
  constructionRecipe = previous.recipes.bison;
  candidate = import ../../../bases/source-gnu { };
  native = pkgs.stdenv.hostPlatform.system == "x86_64-linux";
  host =
    name: reason:
    tvpLib.packages.withConstraint {
      category = "construction";
      inherit reason;
    } candidate.tools.${name};
  defs = tvpLib.packages.mkDefs {
    "3.8.2" = {
      constructor = tvp.builder;
      builder = ./native/build-3.8.2.nix;
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
        perl = tvp.packages.perl_5;
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
    "3.0.5" = {
      constructor = tvp.builder;
      builder = ./ordinary/build-3.0.5.nix;
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
        patch = candidate.tools.patch;
        testAutoconf = tvp.packages.autoconf;
        m4 = tvp.packages.m4_1;
        perl = tvp.packages.perl_5;
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
    "3.1" = {
      constructor = tvp.builder;
      builder = ./ordinary/build-3.1.nix;
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
        patch = candidate.tools.patch;
        testAutoconf = tvp.packages.autoconf;
        m4 = tvp.packages.m4_1;
        perl = tvp.packages.perl_5;
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
    "3.3.2" = {
      constructor = tvp.builder;
      builder = ./ordinary/build-3.3.2.nix;
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
        patch = candidate.tools.patch;
        testAutoconf = tvp.packages.autoconf;
        m4 = tvp.packages.m4_1;
        perl = tvp.packages.perl_5;
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
    "3.4.2" = {
      constructor = tvp.builder;
      builder = ./ordinary/build-3.4.2.nix;
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
      opts.postPatch = "touch -r doc/bison.1 configure";
      patches = [
        {
          file = ./reccalc-without-flex.patch;
          reason = "Initialize LEX_IS_FLEX when Flex is absent; preserve shipped manual timestamps.";
        }
      ];
      deps = {
        patch = candidate.tools.patch;
        testAutoconf = tvp.packages.autoconf;
        m4 = tvp.packages.m4_1;
        perl = tvp.packages.perl_5;
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
    "3.6.4" = {
      constructor = tvp.builder;
      builder = ./ordinary/build-3.6.4.nix;
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
      patches = [
        {
          file = ./patches/3.6.4-relative-compiler-inputs.patch;
          reason = "Pass generated @-prefixed C/C++ filenames as explicit relative paths; preserve every filename assertion while avoiding the compiler wrapper's response-file syntax.";
        }
      ];
      deps = {
        patch = candidate.tools.patch;
        testAutoconf = tvp.packages.autoconf;
        m4 = tvp.packages.m4_1;
        perl = tvp.packages.perl_5;
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
    "3.8" = {
      constructor = tvp.builder;
      builder = ./ordinary/build-3.8.nix;
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
        patch = candidate.tools.patch;
        testAutoconf = tvp.packages.autoconf;
        m4 = tvp.packages.m4_1;
        perl = tvp.packages.perl_5;
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
    "3.8.2" = constructionRecipe.versionTable."3.8.2" // {
      def = if native then defs."3.8.2" else constructionRecipe.versionTable."3.8.2".def;
    };
    "3.0.5" = constructionRecipe.versionTable."3.0.5" // {
      def = if native then defs."3.0.5" else constructionRecipe.versionTable."3.0.5".def;
    };
    "3.1" = constructionRecipe.versionTable."3.1" // {
      def = if native then defs."3.1" else constructionRecipe.versionTable."3.1".def;
    };
    "3.2.4" = constructionRecipe.versionTable."3.2.4" // {
      def = if native then defs."3.1" else constructionRecipe.versionTable."3.2.4".def;
    };
    "3.3.2" = constructionRecipe.versionTable."3.3.2" // {
      def = if native then defs."3.3.2" else constructionRecipe.versionTable."3.3.2".def;
    };
    "3.4.2" = constructionRecipe.versionTable."3.4.2" // {
      def = if native then defs."3.4.2" else constructionRecipe.versionTable."3.4.2".def;
    };
    "3.5.4" = constructionRecipe.versionTable."3.5.4" // {
      def = if native then defs."3.3.2" else constructionRecipe.versionTable."3.5.4".def;
    };
    "3.6.4" = constructionRecipe.versionTable."3.6.4" // {
      def = if native then defs."3.6.4" else constructionRecipe.versionTable."3.6.4".def;
    };
    "3.7.6" = constructionRecipe.versionTable."3.7.6" // {
      def = if native then defs."3.6.4" else constructionRecipe.versionTable."3.7.6".def;
    };
    "3.8" = constructionRecipe.versionTable."3.8" // {
      def = if native then defs."3.8" else constructionRecipe.versionTable."3.8".def;
    };
    "3.8.1" = constructionRecipe.versionTable."3.8.1" // {
      def = if native then defs."3.8" else constructionRecipe.versionTable."3.8.1".def;
    };
  };

  publicArgs = constructionRecipe // {
    inherit versionTable;
    source =
      { version, sha256 }:
      pkgs.fetchurl {
        url = "https://mirrors.kernel.org/gnu/bison/bison-${version}.tar.gz";
        inherit sha256;
      };
    testDeps = {
      sentinel = (import ../../../bases/source-gnu/tests/probes.nix { }).sentinel;
      alternateSource = (import ../../../bootstrap/source-cmake-prerequisite-tests.nix { }).alternate;
      flex = tvp.packages.flex;
    };
    extraArgs.mkTests = pkgs.lib.makeOverridable (
      { pkgs }:
      package:
      if package ? testContext then
        import
          (
            if
              builtins.elem package.version [
                "3.0.5"
                "3.1"
                "3.2.4"
                "3.3.2"
                "3.4.2"
                "3.5.4"
                "3.6.4"
                "3.7.6"
                "3.8"
                "3.8.1"
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
    ) { inherit pkgs; };
  };
  canonical = tvpLib.packages.mkVersions publicArgs;
  pname = "bison";
in
{
  recipes.${pname} = publicArgs // {
    inherit constructionRecipe;
  };
  inherit canonical;
  aliases = tvpLib.packages.mkAliases { inherit pname versionTable canonical; };
}

{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  previous = import ./legacy.nix { inherit pkgs tvp; };
  constructionRecipe = previous.recipes.autoconf;
  candidate = import ../../../bases/source-gnu { };
  native = pkgs.stdenv.hostPlatform.system == "x86_64-linux";
  host =
    name: reason:
    tvpLib.packages.withConstraint {
      category = "construction";
      inherit reason;
    } candidate.tools.${name};
  defs = tvpLib.packages.mkDefs {
    "2.10" = {
      constructor = tvp.builder;
      builder = ./ordinary/build-2.10.nix;
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
        m4 = tvp.packages.m4;
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
      };
      opts.modernInit = false;
      opts.license = pkgs.lib.licenses.gpl2Plus;
    };
    "2.12" = {
      constructor = tvp.builder;
      builder = ./ordinary/build-2.10.nix;
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
        m4 = tvp.packages.m4;
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
      };
      opts.modernInit = false;
      opts.license = pkgs.lib.licenses.gpl2Plus;
      # AC_PROG_CC_WORKS emits implicit-int main(), requiring its C89 dialect.
      opts.consumerCStandard = "gnu89";
    };
    "2.50" = {
      constructor = tvp.builder;
      builder = ./ordinary/build-2.50.nix;
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
        m4 = tvp.packages.m4;
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
      };
      opts.license = pkgs.lib.licenses.gpl2Plus;
    };
    "2.53" = {
      constructor = tvp.builder;
      builder = ./ordinary/build-2.50.nix;
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
        m4 = tvp.packages.m4;
        perl = tvpLib.packages.withConstraint {
          reason = "autom4te uses do on relative autom4te.cache/requests; Perl 5.26 removes dot from @INC. Native 2.53 passes with 5.24 and fails with 5.28; Autoconf 2.58 replaces this lookup with read/eval.";
        } tvp.packages.perl_5_24;
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
      };
      opts.license = pkgs.lib.licenses.gpl2Plus;
    };
    "2.65" = {
      constructor = tvp.builder;
      builder = ./ordinary/build-2.65.nix;
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
      };
    };
    "2.72" = {
      constructor = tvp.builder;
      builder = ./ordinary/build-2.72.nix;
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
      };
    };
    "2.73" = {
      constructor = tvp.builder;
      builder = ./native/build-2.73.nix;
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
      };
    };
  };
  versionTable = constructionRecipe.versionTable // {
    "2.10" = constructionRecipe.versionTable."2.10" // {
      def = if native then defs."2.10" else constructionRecipe.versionTable."2.10".def;
    };
    "2.11" = constructionRecipe.versionTable."2.11" // {
      def = if native then defs."2.10" else constructionRecipe.versionTable."2.11".def;
    };
    "2.12" = constructionRecipe.versionTable."2.12" // {
      def = if native then defs."2.12" else constructionRecipe.versionTable."2.12".def;
    };
    "2.13" = constructionRecipe.versionTable."2.13" // {
      def = if native then defs."2.12" else constructionRecipe.versionTable."2.13".def;
    };
    "2.50" = constructionRecipe.versionTable."2.50" // {
      def = if native then defs."2.50" else constructionRecipe.versionTable."2.50".def;
    };
    "2.52" = constructionRecipe.versionTable."2.52" // {
      def = if native then defs."2.50" else constructionRecipe.versionTable."2.52".def;
    };
    "2.53" = constructionRecipe.versionTable."2.53" // {
      def = if native then defs."2.53" else constructionRecipe.versionTable."2.53".def;
    };
    "2.54" = constructionRecipe.versionTable."2.54" // {
      def = if native then defs."2.53" else constructionRecipe.versionTable."2.54".def;
    };
    "2.55" = constructionRecipe.versionTable."2.55" // {
      def = if native then defs."2.53" else constructionRecipe.versionTable."2.55".def;
    };
    "2.56" = constructionRecipe.versionTable."2.56" // {
      def = if native then defs."2.53" else constructionRecipe.versionTable."2.56".def;
    };
    "2.57" = constructionRecipe.versionTable."2.57" // {
      def = if native then defs."2.53" else constructionRecipe.versionTable."2.57".def;
    };
    "2.58" = constructionRecipe.versionTable."2.58" // {
      def = if native then defs."2.50" else constructionRecipe.versionTable."2.58".def;
    };
    "2.59" = constructionRecipe.versionTable."2.59" // {
      def = if native then defs."2.50" else constructionRecipe.versionTable."2.59".def;
    };
    "2.60" = constructionRecipe.versionTable."2.60" // {
      def = if native then defs."2.50" else constructionRecipe.versionTable."2.60".def;
    };
    "2.61" = constructionRecipe.versionTable."2.61" // {
      def = if native then defs."2.50" else constructionRecipe.versionTable."2.61".def;
    };
    "2.62" = constructionRecipe.versionTable."2.62" // {
      def = if native then defs."2.50" else constructionRecipe.versionTable."2.62".def;
    };
    "2.63" = constructionRecipe.versionTable."2.63" // {
      def = if native then defs."2.50" else constructionRecipe.versionTable."2.63".def;
    };
    "2.64" = constructionRecipe.versionTable."2.64" // {
      def = if native then defs."2.50" else constructionRecipe.versionTable."2.64".def;
    };
    "2.65" = constructionRecipe.versionTable."2.65" // {
      def = if native then defs."2.65" else constructionRecipe.versionTable."2.65".def;
    };
    "2.66" = constructionRecipe.versionTable."2.66" // {
      def = if native then defs."2.65" else constructionRecipe.versionTable."2.66".def;
    };
    "2.67" = constructionRecipe.versionTable."2.67" // {
      def = if native then defs."2.65" else constructionRecipe.versionTable."2.67".def;
    };
    "2.68" = constructionRecipe.versionTable."2.68" // {
      def = if native then defs."2.65" else constructionRecipe.versionTable."2.68".def;
    };
    "2.69" = constructionRecipe.versionTable."2.69" // {
      def = if native then defs."2.65" else constructionRecipe.versionTable."2.69".def;
    };
    "2.70" = constructionRecipe.versionTable."2.70" // {
      def = if native then defs."2.65" else constructionRecipe.versionTable."2.70".def;
    };
    "2.71" = constructionRecipe.versionTable."2.71" // {
      def = if native then defs."2.65" else constructionRecipe.versionTable."2.71".def;
    };
    "2.72" = constructionRecipe.versionTable."2.72" // {
      def = if native then defs."2.72" else constructionRecipe.versionTable."2.72".def;
    };

    "2.73" = constructionRecipe.versionTable."2.73" // {
      def = if native then defs."2.73" else constructionRecipe.versionTable."2.73".def;
    };
  };
  publicArgs = constructionRecipe // {
    inherit versionTable;
    source =
      { version, sha256 }:
      pkgs.fetchurl {
        urls = [
          "https://mirrors.kernel.org/gnu/autoconf/autoconf-${version}.tar.gz"
          "https://ftp.gnu.org/gnu/autoconf/autoconf-${version}.tar.gz"
        ];
        inherit sha256;
      };
    testDeps = {
      automake = tvp.packages.automake_1;
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
  pname = "autoconf";
in
{
  recipes.${pname} = publicArgs // {
    inherit constructionRecipe;
  };
  inherit canonical;
  aliases = tvpLib.packages.mkAliases {
    lines = [ "2_13" ];
    inherit pname versionTable canonical;
  };
}

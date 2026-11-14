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
        perl = tvp.packages.perl_5;
        bash = tvp.packages.bash_5;
        coreutils = tvp.packages.coreutils_9;
        gnumake = tvp.packages.gnumake_4;
        gnutar = tvp.packages.gnutar_1;
        gzip = tvp.packages.gzip_1;
        bzip2 = tvp.packages.bzip2_1;
        xz = tvp.packages.xz_5;
        patch = tvp.packages.patch_2;
        findutils = tvp.packages.findutils_4;
        sed = tvp.packages.gnused_4;
        grep = tvp.packages.gnugrep_3;
        gawk = tvp.packages.gawk_5;
        diffutils = tvp.packages.diffutils_3;
        python = host "python" "Independent source/output helper avoids public Python -> pkg-config -> Autoconf.";
      };
      opts.automaticCcCo = false;
      opts.archiveExt = "tar.gz";
      opts.headerMacro = "AC_CONFIG_HEADER";
      opts.hasAclocal = false;
    };
    "1.2" = {
      constructor = tvp.builder;
      builder = ./ordinary/build-1.2.nix;
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
        autoconf = tvpLib.packages.withConstraint {
          reason = "1.2/1.3 define AM_PROG_INSTALL unquoted; Autoconf 2.50 aliases that name to AC_PROG_INSTALL, causing macro recursion and an unset INSTALL. Native bootstrap/header controls pass on 2.13 and fail on 2.50 and 2.73.";
        } tvp.packages.autoconf_2_13;
        perl = tvp.packages.perl_5;
        bash = tvp.packages.bash_5;
        coreutils = tvp.packages.coreutils_9;
        gnumake = tvp.packages.gnumake_4;
        gnutar = tvp.packages.gnutar_1;
        gzip = tvp.packages.gzip_1;
        bzip2 = tvp.packages.bzip2_1;
        xz = tvp.packages.xz_5;
        patch = tvp.packages.patch_2;
        findutils = tvp.packages.findutils_4;
        sed = tvp.packages.gnused_4;
        grep = tvp.packages.gnugrep_3;
        gawk = tvp.packages.gawk_5;
        diffutils = tvp.packages.diffutils_3;
        python = host "python" "Independent source/output helper avoids public Python -> pkg-config -> Autoconf.";
      };
      opts.automaticCcCo = false;
      opts.archiveExt = "tar.gz";
      opts.headerMacro = "AM_CONFIG_HEADER";
    };
    "1.4" = {
      constructor = tvp.builder;
      builder = ./ordinary/build-1.2.nix;
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
        gzip = tvp.packages.gzip_1;
        bzip2 = tvp.packages.bzip2_1;
        xz = tvp.packages.xz_5;
        patch = tvp.packages.patch_2;
        findutils = tvp.packages.findutils_4;
        sed = tvp.packages.gnused_4;
        grep = tvp.packages.gnugrep_3;
        gawk = tvp.packages.gawk_5;
        diffutils = tvp.packages.diffutils_3;
        python = host "python" "Independent source/output helper avoids public Python -> pkg-config -> Autoconf.";
      };
      opts.automaticCcCo = false;
      opts.archiveExt = "tar.gz";
      opts.headerMacro = "AM_CONFIG_HEADER";
      patches = [
        {
          file = ./patches/1.4-perl-indirect-call.patch;
          reason = "Perl 5.20 removed do SUBROUTINE(LIST); call the language handlers through their symbolic references instead.";
        }
      ];
    };
    "1.5" = {
      constructor = tvp.builder;
      builder = ./ordinary/build-1.2.nix;
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
        gzip = tvp.packages.gzip_1;
        bzip2 = tvp.packages.bzip2_1;
        xz = tvp.packages.xz_5;
        patch = tvp.packages.patch_2;
        findutils = tvp.packages.findutils_4;
        sed = tvp.packages.gnused_4;
        grep = tvp.packages.gnugrep_3;
        gawk = tvp.packages.gawk_5;
        diffutils = tvp.packages.diffutils_3;
        python = host "python" "Independent source/output helper avoids public Python -> pkg-config -> Autoconf.";
      };
      opts.automaticCcCo = false;
      opts.archiveExt = "tar.gz";
      opts.headerMacro = "AM_CONFIG_HEADER";
    };
    "1.6" = {
      constructor = tvp.builder;
      builder = ./ordinary/build-1.6.nix;
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
        gzip = tvp.packages.gzip_1;
        bzip2 = tvp.packages.bzip2_1;
        xz = tvp.packages.xz_5;
        patch = tvp.packages.patch_2;
        findutils = tvp.packages.findutils_4;
        sed = tvp.packages.gnused_4;
        grep = tvp.packages.gnugrep_3;
        gawk = tvp.packages.gawk_5;
        diffutils = tvp.packages.diffutils_3;
        python = host "python" "Independent source/output helper avoids public Python -> pkg-config -> Autoconf.";
      };
      opts.automaticCcCo = false;
      opts.archiveExt = "tar.gz";
      opts.headerMacro = "AM_CONFIG_HEADER";
    };
    "1.6.1" = {
      constructor = tvp.builder;
      builder = ./ordinary/build-1.6.nix;
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
        gzip = tvp.packages.gzip_1;
        bzip2 = tvp.packages.bzip2_1;
        xz = tvp.packages.xz_5;
        patch = tvp.packages.patch_2;
        findutils = tvp.packages.findutils_4;
        sed = tvp.packages.gnused_4;
        grep = tvp.packages.gnugrep_3;
        gawk = tvp.packages.gawk_5;
        diffutils = tvp.packages.diffutils_3;
        python = host "python" "Independent source/output helper avoids public Python -> pkg-config -> Autoconf.";
      };
      opts.automaticCcCo = false;
      opts.archiveExt = "tar.bz2";
      opts.headerMacro = "AM_CONFIG_HEADER";
    };
    "1.7" = {
      constructor = tvp.builder;
      builder = ./ordinary/build-1.6.nix;
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
        gzip = tvp.packages.gzip_1;
        bzip2 = tvp.packages.bzip2_1;
        xz = tvp.packages.xz_5;
        patch = tvp.packages.patch_2;
        findutils = tvp.packages.findutils_4;
        sed = tvp.packages.gnused_4;
        grep = tvp.packages.gnugrep_3;
        gawk = tvp.packages.gawk_5;
        diffutils = tvp.packages.diffutils_3;
        python = host "python" "Independent source/output helper avoids public Python -> pkg-config -> Autoconf.";
      };
      opts.automaticCcCo = false;
      opts.archiveExt = "tar.bz2";
    };
    "1.8" = {
      constructor = tvp.builder;
      builder = ./ordinary/build-1.6.nix;
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
        gzip = tvp.packages.gzip_1;
        bzip2 = tvp.packages.bzip2_1;
        xz = tvp.packages.xz_5;
        patch = tvp.packages.patch_2;
        findutils = tvp.packages.findutils_4;
        sed = tvp.packages.gnused_4;
        grep = tvp.packages.gnugrep_3;
        gawk = tvp.packages.gawk_5;
        diffutils = tvp.packages.diffutils_3;
        python = host "python" "Independent source/output helper avoids public Python -> pkg-config -> Autoconf.";
      };
      opts.automaticCcCo = false;
      opts.archiveExt = "tar.bz2";
      patches = [
        {
          file = ./patches/1.8-load-exporter.patch;
          reason = "Automake::Config inherits from Exporter without loading it, leaving aclocal's version and macro directory unset on modern Perl.";
        }
      ];
    };
    "1.10" = {
      constructor = tvp.builder;
      builder = ./ordinary/build-1.6.nix;
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
        gzip = tvp.packages.gzip_1;
        bzip2 = tvp.packages.bzip2_1;
        xz = tvp.packages.xz_5;
        patch = tvp.packages.patch_2;
        findutils = tvp.packages.findutils_4;
        sed = tvp.packages.gnused_4;
        grep = tvp.packages.gnugrep_3;
        gawk = tvp.packages.gawk_5;
        diffutils = tvp.packages.diffutils_3;
        python = host "python" "Independent source/output helper avoids public Python -> pkg-config -> Autoconf.";
      };
      opts.archiveExt = "tar.bz2";
    };
    "1.11" = {
      constructor = tvp.builder;
      builder = ./ordinary/build-1.6.nix;
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
        gzip = tvp.packages.gzip_1;
        bzip2 = tvp.packages.bzip2_1;
        xz = tvp.packages.xz_5;
        patch = tvp.packages.patch_2;
        findutils = tvp.packages.findutils_4;
        sed = tvp.packages.gnused_4;
        grep = tvp.packages.gnugrep_3;
        gawk = tvp.packages.gawk_5;
        diffutils = tvp.packages.diffutils_3;
        python = host "python" "Independent source/output helper avoids public Python -> pkg-config -> Autoconf.";
      };
      opts.archiveExt = "tar.bz2";
      opts.installAclocalDir = true;
    };
    "1.11.3" = {
      constructor = tvp.builder;
      builder = ./ordinary/build-1.6.nix;
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
        gzip = tvp.packages.gzip_1;
        bzip2 = tvp.packages.bzip2_1;
        xz = tvp.packages.xz_5;
        patch = tvp.packages.patch_2;
        findutils = tvp.packages.findutils_4;
        sed = tvp.packages.gnused_4;
        grep = tvp.packages.gnugrep_3;
        gawk = tvp.packages.gawk_5;
        diffutils = tvp.packages.diffutils_3;
        python = host "python" "Independent source/output helper avoids public Python -> pkg-config -> Autoconf.";
      };
      opts.installAclocalDir = true;
    };
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
    "1.0" = constructionRecipe.versionTable."1.0" // {
      def = if native then defs."1.0" else constructionRecipe.versionTable."1.0".def;
    };
    "1.2" = constructionRecipe.versionTable."1.2" // {
      def = if native then defs."1.2" else constructionRecipe.versionTable."1.2".def;
    };
    "1.3" = constructionRecipe.versionTable."1.3" // {
      def = if native then defs."1.2" else constructionRecipe.versionTable."1.3".def;
    };
    "1.4" = constructionRecipe.versionTable."1.4" // {
      def = if native then defs."1.4" else constructionRecipe.versionTable."1.4".def;
    };
    "1.4-p1" = constructionRecipe.versionTable."1.4-p1" // {
      def = if native then defs."1.4" else constructionRecipe.versionTable."1.4-p1".def;
    };
    "1.4-p2" = constructionRecipe.versionTable."1.4-p2" // {
      def = if native then defs."1.4" else constructionRecipe.versionTable."1.4-p2".def;
    };
    "1.4-p3" = constructionRecipe.versionTable."1.4-p3" // {
      def = if native then defs."1.4" else constructionRecipe.versionTable."1.4-p3".def;
    };
    "1.4-p4" = constructionRecipe.versionTable."1.4-p4" // {
      def = if native then defs."1.4" else constructionRecipe.versionTable."1.4-p4".def;
    };
    "1.4-p5" = constructionRecipe.versionTable."1.4-p5" // {
      def = if native then defs."1.4" else constructionRecipe.versionTable."1.4-p5".def;
    };
    "1.4-p6" = constructionRecipe.versionTable."1.4-p6" // {
      def = if native then defs."1.4" else constructionRecipe.versionTable."1.4-p6".def;
    };
    "1.5" = constructionRecipe.versionTable."1.5" // {
      def = if native then defs."1.5" else constructionRecipe.versionTable."1.5".def;
    };
    "1.6" = constructionRecipe.versionTable."1.6" // {
      def = if native then defs."1.6" else constructionRecipe.versionTable."1.6".def;
    };
    "1.6.1" = constructionRecipe.versionTable."1.6.1" // {
      def = if native then defs."1.6.1" else constructionRecipe.versionTable."1.6.1".def;
    };
    "1.6.2" = constructionRecipe.versionTable."1.6.2" // {
      def = if native then defs."1.6.1" else constructionRecipe.versionTable."1.6.2".def;
    };
    "1.6.3" = constructionRecipe.versionTable."1.6.3" // {
      def = if native then defs."1.6.1" else constructionRecipe.versionTable."1.6.3".def;
    };
    "1.7" = constructionRecipe.versionTable."1.7" // {
      def = if native then defs."1.7" else constructionRecipe.versionTable."1.7".def;
    };
    "1.7.1" = constructionRecipe.versionTable."1.7.1" // {
      def = if native then defs."1.7" else constructionRecipe.versionTable."1.7.1".def;
    };
    "1.7.2" = constructionRecipe.versionTable."1.7.2" // {
      def = if native then defs."1.7" else constructionRecipe.versionTable."1.7.2".def;
    };
    "1.7.3" = constructionRecipe.versionTable."1.7.3" // {
      def = if native then defs."1.7" else constructionRecipe.versionTable."1.7.3".def;
    };
    "1.7.4" = constructionRecipe.versionTable."1.7.4" // {
      def = if native then defs."1.7" else constructionRecipe.versionTable."1.7.4".def;
    };
    "1.7.5" = constructionRecipe.versionTable."1.7.5" // {
      def = if native then defs."1.7" else constructionRecipe.versionTable."1.7.5".def;
    };
    "1.7.6" = constructionRecipe.versionTable."1.7.6" // {
      def = if native then defs."1.7" else constructionRecipe.versionTable."1.7.6".def;
    };
    "1.7.7" = constructionRecipe.versionTable."1.7.7" // {
      def = if native then defs."1.7" else constructionRecipe.versionTable."1.7.7".def;
    };
    "1.7.8" = constructionRecipe.versionTable."1.7.8" // {
      def = if native then defs."1.7" else constructionRecipe.versionTable."1.7.8".def;
    };
    "1.7.9" = constructionRecipe.versionTable."1.7.9" // {
      def = if native then defs."1.7" else constructionRecipe.versionTable."1.7.9".def;
    };
    "1.8" = constructionRecipe.versionTable."1.8" // {
      def = if native then defs."1.8" else constructionRecipe.versionTable."1.8".def;
    };
    "1.8.1" = constructionRecipe.versionTable."1.8.1" // {
      def = if native then defs."1.7" else constructionRecipe.versionTable."1.8.1".def;
    };
    "1.8.2" = constructionRecipe.versionTable."1.8.2" // {
      def = if native then defs."1.7" else constructionRecipe.versionTable."1.8.2".def;
    };
    "1.8.3" = constructionRecipe.versionTable."1.8.3" // {
      def = if native then defs."1.7" else constructionRecipe.versionTable."1.8.3".def;
    };
    "1.8.4" = constructionRecipe.versionTable."1.8.4" // {
      def = if native then defs."1.7" else constructionRecipe.versionTable."1.8.4".def;
    };
    "1.8.5" = constructionRecipe.versionTable."1.8.5" // {
      def = if native then defs."1.7" else constructionRecipe.versionTable."1.8.5".def;
    };
    "1.9" = constructionRecipe.versionTable."1.9" // {
      def = if native then defs."1.7" else constructionRecipe.versionTable."1.9".def;
    };
    "1.9.1" = constructionRecipe.versionTable."1.9.1" // {
      def = if native then defs."1.7" else constructionRecipe.versionTable."1.9.1".def;
    };
    "1.9.2" = constructionRecipe.versionTable."1.9.2" // {
      def = if native then defs."1.7" else constructionRecipe.versionTable."1.9.2".def;
    };
    "1.9.3" = constructionRecipe.versionTable."1.9.3" // {
      def = if native then defs."1.7" else constructionRecipe.versionTable."1.9.3".def;
    };
    "1.9.4" = constructionRecipe.versionTable."1.9.4" // {
      def = if native then defs."1.7" else constructionRecipe.versionTable."1.9.4".def;
    };
    "1.9.5" = constructionRecipe.versionTable."1.9.5" // {
      def = if native then defs."1.7" else constructionRecipe.versionTable."1.9.5".def;
    };
    "1.9.6" = constructionRecipe.versionTable."1.9.6" // {
      def = if native then defs."1.7" else constructionRecipe.versionTable."1.9.6".def;
    };
    "1.10" = constructionRecipe.versionTable."1.10" // {
      def = if native then defs."1.10" else constructionRecipe.versionTable."1.10".def;
    };
    "1.10.1" = constructionRecipe.versionTable."1.10.1" // {
      def = if native then defs."1.10" else constructionRecipe.versionTable."1.10.1".def;
    };
    "1.10.2" = constructionRecipe.versionTable."1.10.2" // {
      def = if native then defs."1.10" else constructionRecipe.versionTable."1.10.2".def;
    };
    "1.10.3" = constructionRecipe.versionTable."1.10.3" // {
      def = if native then defs."1.10" else constructionRecipe.versionTable."1.10.3".def;
    };
    "1.11" = constructionRecipe.versionTable."1.11" // {
      def = if native then defs."1.11" else constructionRecipe.versionTable."1.11".def;
    };
    "1.11.1" = constructionRecipe.versionTable."1.11.1" // {
      def = if native then defs."1.11" else constructionRecipe.versionTable."1.11.1".def;
    };
    "1.11.2" = constructionRecipe.versionTable."1.11.2" // {
      def = if native then defs."1.11" else constructionRecipe.versionTable."1.11.2".def;
    };
    "1.11.3" = constructionRecipe.versionTable."1.11.3" // {
      def = if native then defs."1.11.3" else constructionRecipe.versionTable."1.11.3".def;
    };
    "1.11.4" = constructionRecipe.versionTable."1.11.4" // {
      def = if native then defs."1.11.3" else constructionRecipe.versionTable."1.11.4".def;
    };
    "1.11.5" = constructionRecipe.versionTable."1.11.5" // {
      def = if native then defs."1.11.3" else constructionRecipe.versionTable."1.11.5".def;
    };
    "1.11.6" = constructionRecipe.versionTable."1.11.6" // {
      def = if native then defs."1.11.3" else constructionRecipe.versionTable."1.11.6".def;
    };
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
      { version, sha256, ... }:
      pkgs.fetchurl {
        urls =
          [
            "https://mirrors.kernel.org/gnu/automake/automake-${version}.${
              versionTable.${version}.def.opts.archiveExt or "tar.xz"
            }"
          ]
          ++ pkgs.lib.optional (version == "1.19")
            "https://ftp.gnu.org/gnu/automake/automake-${version}.${
              versionTable.${version}.def.opts.archiveExt or "tar.xz"
            }";
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

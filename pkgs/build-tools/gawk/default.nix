{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  defs = tvpLib.packages.mkDefs {
    "3.0.6" = {
      builder = ./build-3.0.6.nix;
      base = tvp.bases.default;
      deps = { };
      opts = {
        hardeningDisable = [ "format" ];
        # K&R probes and empty parameter lists predate modern C semantics.
        cStandard = "gnu89";
        archiveExt = "tar.gz";
        license = pkgs.lib.licenses.gpl2Plus;
      };
    };
    "3.1.8" = {
      # Retain pre-C23 non-prototype semantics (GCC porting guidance).
      opts = {
        hardeningDisable = [ "format" ];
        cStandard = "gnu89";
      };
      builder = ./build-3.0.6.nix;
      base = tvp.bases.default;
      deps = { };
    };
    "4.0.2" = {
      builder = ./build-4.0.2.nix;
      base = tvp.bases.default;
      # Empty read/math callback prototypes require pre-C23 semantics.
      opts.cStandard = "gnu17";
      deps = {
        readline = tvp.packages.readline_8;
        ncurses = tvp.packages.ncurses_6;
      };
    };
    "4.1.4" = {
      builder = ./build-4.1.4.nix;
      base = tvp.bases.default;
      # Empty read/math callback prototypes require pre-C23 semantics.
      opts.cStandard = "gnu17";
      # The readline sanity probe calls open/close/dup without their headers.
      # Keep the real runtime probe, demoting this diagnostic only in configure.
      opts.configureCFlags = [ "-Wno-error=implicit-function-declaration" ];
      deps = {
        gmp = tvp.packages.gmp_6;
        mpfr = tvp.packages.mpfr_4;
        readline = tvp.packages.readline_8;
        ncurses = tvp.packages.ncurses_6;
      };
    };
    "5.1.1" = {
      builder = ./build-4.1.4.nix;
      base = tvp.bases.default;
      opts.cStandard = "gnu17";
      deps = {
        gmp = tvp.packages.gmp_6;
        mpfr = tvp.packages.mpfr_4;
        readline = tvp.packages.readline_8;
        ncurses = tvp.packages.ncurses_6;
      };
    };
    "5.3.1" = {
      builder = ./build-4.1.4.nix;
      base = tvp.bases.default;
      deps = {
        gmp = tvp.packages.gmp_6;
        mpfr = tvp.packages.mpfr_4;
        readline = tvp.packages.readline_8;
        ncurses = tvp.packages.ncurses_6;
      };
    };

  };
  versionTable = tvpLib.packages.mkTable [
    {
      def = defs."3.0.6";
      releases."3.0.6" = "sha256-q/J24Qx7hxMy0HvytlITOidBlnfRVzgwl7vRU+WKi/w=";
    }
    {
      def = defs."3.1.8";
      releases."3.1.8" = "sha256-Xbx7LEwyhxEzfCqs0JoSLHMTEiJi4/8DRZDwFAZ0ErQ=";
    }

    {
      def = defs."4.0.2";
      releases."4.0.2" = "sha256-IeHyjFG1Fg8KS/GnNcYQm0ajvWpD3oCOq8IcF7sCbRM=";
    }
    {
      def = defs."4.1.4";
      releases."5.0.1" = "sha256-jk6G8E7XiWSLZvdXMpdDoNbftSlMO5G3VqR08c4Fp5Q=";
      releases."4.2.1" = "sha256-0RGXhedG1GqCCdKLLeQEpX+YOqSGcPTiJVMdO9wXVVE=";
      releases."4.1.4" = "sha256-U+GE4tD5De+SB4YFMYAkVjIr4JHHtI8j/cec2mWtwmY=";
    }
    {
      def = defs."5.3.1";
      releases."5.3.1" = "sha256-aU23ZIEqYjZCPU/0DOt7bExEEwG3KtUCu1wn4AzVb3g=";
      releases."5.3.2" = "sha256-+MNIZQnecFGSE4sA7ywAu73Q6Eww1cB9I/xzqdxMycw=";
      releases."5.4.0" = "sha256-PdQw8M07RCjGw/avwCG5zTwfjJP3pojcJoykKKkLSsE=";
      releases."5.4.1" = "sha256-B/b3NCt/6+QxP8LCVCrZPWT+IK2HFyABCfEFqCb1/Tc=";
    }
    {
      def = defs."5.1.1";
      releases."5.1.1" = "sha256-2HYpOG6JS76hGl4AUV/JCdybcklSna2eajosdwhffqI=";
      releases."5.2.2" = "sha256-PB/OFEa0y+4c0nO9fsZLyH2J9hU3RxzT4F4zqWWiUOk=";
      releases."5.3.0" = "sha256-ypwW09EdD/jGnXncC0cmfhMppps5t5mJVgTtRH08qQs=";
    }
  ];
  pname = "gawk";
  packageArgs = {
    infra = {
      inherit (pkgs) lib fetchurl;
    };
    inherit pname versionTable;
    packageMeta.upstream = import ./upstream.nix;
    extraArgs.mkTests =
      package:
      import ./tests {
        inherit tvpLib package;
        pkgs = tvpLib.tests.withBase {
          inherit pkgs;
          base.stdenv = package.stdenv;
        };
      };
  };
  # Complete legacy call: table, factories, source construction and test routing.
  constructionRecipe = packageArgs;
  candidate = import ../../../bases/source-gnu { };
  native = pkgs.stdenv.hostPlatform.system == "x86_64-linux";
  constructionTool =
    name:
    tvpLib.packages.withConstraint {
      category = "construction";
      reason = "Retained source-GNU ${name} is an explicit build-only host generation, independent of these target libraries and commands.";
    } candidate.tools.${name};
  ownedDefs = tvpLib.packages.mkDefs {
    "4.0.2" = {
      constructor = tvp.builder;
      builder = ./ordinary/build-4.0.2.nix;
      base = candidate.base;
      source =
        { version, sha256 }:
        import <nix/fetchurl.nix> {
          url = "https://mirrors.kernel.org/gnu/gawk/gawk-${version}.tar.xz";
          inherit sha256;
        };
      testContext =
        package:
        tvpLib.tests.fromPackage {
          builder = tvp.builder;
          inherit package;
        };
      helpers = {
        inherit tvp;
      };
      deps = {
        bash = constructionTool "bash";
        coreutils = constructionTool "coreutils";
        gnumake = constructionTool "make";
        gnutar = constructionTool "tar";
        python = constructionTool "python";
        binutils = constructionTool "binutils";
        patchelf = constructionTool "patchelf";
        sed = constructionTool "sed";
        grep = constructionTool "grep";
        gawk = constructionTool "gawk";
        diffutils = constructionTool "diffutils";
        findutils = constructionTool "findutils";
        xz = constructionTool "xz";
        perl = constructionTool "perl";
        readline = tvp.packages.readline_8;
        ncurses = tvp.packages.ncurses_6;
        checkLocales = import ./native/check-locales.nix {
          builder = tvp.builder;
          base = candidate.base;
          inherit (candidate.tools)
            bash
            coreutils
            tar
            xz
            ;
          libc = candidate.toolchain.libc;
        };
        localeProvider = tvpLib.packages.withConstraint {
          category = "construction";
          reason = "Matching source-owned target libc locale tools and C.UTF-8 data for upstream Unicode tests.";
        } candidate.toolchain.libc;
      };
    };
    "4.1.4" = {
      constructor = tvp.builder;
      builder = ./ordinary/build-4.1.4.nix;
      base = candidate.base;
      source =
        { version, sha256 }:
        import <nix/fetchurl.nix> {
          url = "https://mirrors.kernel.org/gnu/gawk/gawk-${version}.tar.xz";
          inherit sha256;
        };
      testContext =
        package:
        tvpLib.tests.fromPackage {
          builder = tvp.builder;
          inherit package;
        };
      helpers = {
        inherit tvp;
      };
      deps = {
        bash = constructionTool "bash";
        coreutils = constructionTool "coreutils";
        gnumake = constructionTool "make";
        gnutar = constructionTool "tar";
        python = constructionTool "python";
        binutils = constructionTool "binutils";
        patchelf = constructionTool "patchelf";
        sed = constructionTool "sed";
        grep = constructionTool "grep";
        gawk = constructionTool "gawk";
        diffutils = constructionTool "diffutils";
        findutils = constructionTool "findutils";
        xz = constructionTool "xz";
        perl = constructionTool "perl";
        gmp = tvp.packages.gmp_6;
        mpfr = tvp.packages.mpfr_4;
        readline = tvp.packages.readline_8;
        ncurses = tvp.packages.ncurses_6;
        checkLocales = import ./native/check-locales.nix {
          builder = tvp.builder;
          base = candidate.base;
          inherit (candidate.tools)
            bash
            coreutils
            tar
            xz
            ;
          libc = candidate.toolchain.libc;
        };
        localeProvider = tvpLib.packages.withConstraint {
          category = "construction";
          reason = "Matching source-owned target libc locale tools and C.UTF-8 data for upstream Unicode tests.";
        } candidate.toolchain.libc;
      };
    };
    "5.1.1" = {
      constructor = tvp.builder;
      builder = ./ordinary/build-5.1.1.nix;
      base = candidate.base;
      source =
        { version, sha256 }:
        import <nix/fetchurl.nix> {
          url = "https://mirrors.kernel.org/gnu/gawk/gawk-${version}.tar.xz";
          inherit sha256;
        };
      testContext =
        package:
        tvpLib.tests.fromPackage {
          builder = tvp.builder;
          inherit package;
        };
      helpers = {
        inherit tvp;
      };
      deps = {
        bash = constructionTool "bash";
        coreutils = constructionTool "coreutils";
        gnumake = constructionTool "make";
        gnutar = constructionTool "tar";
        python = constructionTool "python";
        binutils = constructionTool "binutils";
        patchelf = constructionTool "patchelf";
        sed = constructionTool "sed";
        grep = constructionTool "grep";
        gawk = constructionTool "gawk";
        diffutils = constructionTool "diffutils";
        findutils = constructionTool "findutils";
        xz = constructionTool "xz";
        perl = constructionTool "perl";
        gmp = tvp.packages.gmp_6;
        mpfr = tvp.packages.mpfr_4;
        readline = tvp.packages.readline_8;
        ncurses = tvp.packages.ncurses_6;
        checkLocales = import ./native/check-locales.nix {
          builder = tvp.builder;
          base = candidate.base;
          inherit (candidate.tools)
            bash
            coreutils
            tar
            xz
            ;
          libc = candidate.toolchain.libc;
        };
        localeProvider = tvpLib.packages.withConstraint {
          category = "construction";
          reason = "Matching source-owned target libc locale tools and C.UTF-8 data for upstream Unicode tests.";
        } candidate.toolchain.libc;
      };
    };
    "5.3.1" = {
      constructor = tvp.builder;
      builder = ./ordinary/build-5.3.1.nix;
      base = candidate.base;
      source =
        { version, sha256 }:
        import <nix/fetchurl.nix> {
          url = "https://mirrors.kernel.org/gnu/gawk/gawk-${version}.tar.xz";
          inherit sha256;
        };
      testContext =
        package:
        tvpLib.tests.fromPackage {
          builder = tvp.builder;
          inherit package;
        };
      helpers = {
        inherit tvp;
      };
      deps = {
        bash = constructionTool "bash";
        coreutils = constructionTool "coreutils";
        gnumake = constructionTool "make";
        gnutar = constructionTool "tar";
        python = constructionTool "python";
        binutils = constructionTool "binutils";
        patchelf = constructionTool "patchelf";
        sed = constructionTool "sed";
        grep = constructionTool "grep";
        gawk = constructionTool "gawk";
        diffutils = constructionTool "diffutils";
        findutils = constructionTool "findutils";
        xz = constructionTool "xz";
        perl = constructionTool "perl";
        gmp = tvp.packages.gmp_6;
        mpfr = tvp.packages.mpfr_4;
        readline = tvp.packages.readline_8;
        ncurses = tvp.packages.ncurses_6;
        checkLocales = import ./native/check-locales.nix {
          builder = tvp.builder;
          base = candidate.base;
          inherit (candidate.tools)
            bash
            coreutils
            tar
            xz
            ;
          libc = candidate.toolchain.libc;
        };
        localeProvider = tvpLib.packages.withConstraint {
          category = "construction";
          reason = "Matching source-owned target libc locale tools and C.UTF-8 data for upstream Unicode tests.";
        } candidate.toolchain.libc;
      };
    };
    "5.4.1" = {
      constructor = tvp.builder;
      builder = ./native/build-5.4.1.nix;
      base = candidate.base;
      source =
        { version, sha256 }:
        import <nix/fetchurl.nix> {
          url = "https://mirrors.kernel.org/gnu/gawk/gawk-${version}.tar.xz";
          inherit sha256;
        };
      testContext =
        package:
        tvpLib.tests.fromPackage {
          builder = tvp.builder;
          inherit package;
        };
      helpers = {
        inherit tvp;
      };
      deps = {
        bash = constructionTool "bash";
        coreutils = constructionTool "coreutils";
        gnumake = constructionTool "make";
        gnutar = constructionTool "tar";
        python = constructionTool "python";
        binutils = constructionTool "binutils";
        patchelf = constructionTool "patchelf";
        sed = constructionTool "sed";
        grep = constructionTool "grep";
        gawk = constructionTool "gawk";
        diffutils = constructionTool "diffutils";
        findutils = constructionTool "findutils";
        xz = constructionTool "xz";
        perl = constructionTool "perl";
        gmp = tvp.packages.gmp_6;
        mpfr = tvp.packages.mpfr_4;
        readline = tvp.packages.readline_8;
        ncurses = tvp.packages.ncurses_6;
        checkLocales = import ./native/check-locales.nix {
          builder = tvp.builder;
          base = candidate.base;
          inherit (candidate.tools)
            bash
            coreutils
            tar
            xz
            ;
          libc = candidate.toolchain.libc;
        };
        localeProvider = tvpLib.packages.withConstraint {
          category = "construction";
          reason = "Matching source-owned target libc locale tools and C.UTF-8 data for upstream Unicode tests.";
        } candidate.toolchain.libc;
      };
    };
  };
  locale = import ../../../lib/tests/gnu-locale.nix {
    builder = tvp.builder;
    base = candidate.base;
    inherit (candidate.tools)
      bash
      coreutils
      tar
      xz
      ;
    libc = candidate.toolchain.libc;
  };
  publicArgs = packageArgs // {
    versionTable = versionTable // {
      "5.3.1" = versionTable."5.3.1" // {
        def = if native then ownedDefs."5.3.1" else versionTable."5.3.1".def;
      };
      "5.3.2" = versionTable."5.3.2" // {
        def = if native then ownedDefs."5.3.1" else versionTable."5.3.2".def;
      };
      "5.4.0" = versionTable."5.4.0" // {
        def = if native then ownedDefs."5.3.1" else versionTable."5.4.0".def;
      };
      "5.1.1" = versionTable."5.1.1" // {
        def = if native then ownedDefs."5.1.1" else versionTable."5.1.1".def;
      };
      "5.2.2" = versionTable."5.2.2" // {
        def = if native then ownedDefs."5.1.1" else versionTable."5.2.2".def;
      };
      "5.3.0" = versionTable."5.3.0" // {
        def = if native then ownedDefs."5.1.1" else versionTable."5.3.0".def;
      };
      "4.1.4" = versionTable."4.1.4" // {
        def = if native then ownedDefs."4.1.4" else versionTable."4.1.4".def;
      };
      "4.2.1" = versionTable."4.2.1" // {
        def = if native then ownedDefs."4.1.4" else versionTable."4.2.1".def;
      };
      "5.0.1" = versionTable."5.0.1" // {
        def = if native then ownedDefs."4.1.4" else versionTable."5.0.1".def;
      };
      "4.0.2" = versionTable."4.0.2" // {
        def = if native then ownedDefs."4.0.2" else versionTable."4.0.2".def;
      };
      "5.4.1" = versionTable."5.4.1" // {
        def = if native then ownedDefs."5.4.1" else versionTable."5.4.1".def;
      };
    };
    extraArgs.mkTests =
      package:
      if package ? testContext then
        import
          (
            if
              builtins.hasAttr package.version {
                "4.0.2" = true;
                "4.1.4" = true;
                "4.2.1" = true;
                "5.0.1" = true;
                "5.1.1" = true;
                "5.2.2" = true;
                "5.3.0" = true;
                "5.3.1" = true;
                "5.3.2" = true;
                "5.4.0" = true;
              }
            then
              ./tests/ordinary.nix
            else
              ./tests/native-default.nix
          )
          {
            inherit pkgs tvpLib package;
            inherit locale;
          }
      else
        constructionRecipe.extraArgs.mkTests package;
  };
  canonical = tvpLib.packages.mkVersions publicArgs;

in
{
  recipes.${pname} = publicArgs // {
    inherit constructionRecipe;
  };
  inherit canonical;
  aliases = tvpLib.packages.mkAliases { inherit pname versionTable canonical; };
}

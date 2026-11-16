{ pkgs, tvp }:
let
  testBase = tvp.bases.gcc_16.full;
  testTools = testBase.tools;
  locale =
    (tvp.lib.tests.fixtures.forBase {
      builder = tvp.builder;
      base = testBase;
    }).gnuLocale;
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build-3.0.6.nix;

        opts = {
          archiveExt = "tar.gz";
          license = pkgs.lib.licenses.gpl2Plus;
        };
      };
      releases = {
        "3.0.6" = "sha256-q/J24Qx7hxMy0HvytlITOidBlnfRVzgwl7vRU+WKi/w=";
      };
    }
    {
      def = {
        builder = ./build-3.0.6.nix;

      };
      releases = {
        "3.1.8" = "sha256-Xbx7LEwyhxEzfCqs0JoSLHMTEiJi4/8DRZDwFAZ0ErQ=";
      };
    }
    {
      def = {
        builder = ./build-4.0.2.nix;
        deps = {
          readline = tvp.packages.readline_8;
          ncurses = tvp.packages.ncurses_6;
        };
      };
      releases = {
        "4.0.2" = "sha256-IeHyjFG1Fg8KS/GnNcYQm0ajvWpD3oCOq8IcF7sCbRM=";
      };
    }
    {
      def = {
        builder = ./build-4.1.4.nix;
        deps = {
          gmp = tvp.packages.gmp_6;
          mpfr = tvp.packages.mpfr_4;
          readline = tvp.packages.readline_8;
          ncurses = tvp.packages.ncurses_6;
        };
      };
      releases = {
        "4.1.4" = "sha256-U+GE4tD5De+SB4YFMYAkVjIr4JHHtI8j/cec2mWtwmY=";
        "4.2.1" = "sha256-0RGXhedG1GqCCdKLLeQEpX+YOqSGcPTiJVMdO9wXVVE=";
        "5.0.1" = "sha256-jk6G8E7XiWSLZvdXMpdDoNbftSlMO5G3VqR08c4Fp5Q=";
      };
    }
    {
      def = {
        builder = ./build-4.1.4.nix;
        deps = {
          gmp = tvp.packages.gmp_6;
          mpfr = tvp.packages.mpfr_4;
          readline = tvp.packages.readline_8;
          ncurses = tvp.packages.ncurses_6;
        };
        opts = {
          buildFeatures = {
            cStandard = "gnu17";
            configureCFlags = [ ];
          };
          sourceLayout = {
            productionFrontends = [
              "awklib"
              "extension"
              "build-aux"
            ];
            upstreamFrontends = [ "test" ];
          };
        };
      };
      releases = {
        "5.1.1" = "sha256-2HYpOG6JS76hGl4AUV/JCdybcklSna2eajosdwhffqI=";
        "5.2.2" = "sha256-PB/OFEa0y+4c0nO9fsZLyH2J9hU3RxzT4F4zqWWiUOk=";
        "5.3.0" = "sha256-ypwW09EdD/jGnXncC0cmfhMppps5t5mJVgTtRH08qQs=";
      };
    }
    {
      def = {
        builder = ./build-4.1.4.nix;
        deps = {
          gmp = tvp.packages.gmp_6;
          mpfr = tvp.packages.mpfr_4;
          readline = tvp.packages.readline_8;
          ncurses = tvp.packages.ncurses_6;
        };
        opts = {
          buildFeatures = {
            cStandard = null;
            configureCFlags = [ ];
          };
          sourceLayout = {
            productionFrontends = [
              "awklib"
              "extension"
              "build-aux"
            ];
            upstreamFrontends = [ "test" ];
          };
        };
      };
      releases = {
        "5.3.1" = "sha256-aU23ZIEqYjZCPU/0DOt7bExEEwG3KtUCu1wn4AzVb3g=";
        "5.3.2" = "sha256-+MNIZQnecFGSE4sA7ywAu73Q6Eww1cB9I/xzqdxMycw=";
        "5.4.0" = "sha256-PdQw8M07RCjGw/avwCG5zTwfjJP3pojcJoykKKkLSsE=";
      };
    }
    {
      def = {
        builder = ./build-5.4.1.nix;
        deps = {
          gmp = tvp.packages.gmp_6;
          mpfr = tvp.packages.mpfr_4;
          readline = tvp.packages.readline_8;
          ncurses = tvp.packages.ncurses_6;
        };
      };
      releases = {
        "5.4.1" = "sha256-B/b3NCt/6+QxP8LCVCrZPWT+IK2HFyABCfEFqCb1/Tc=";
      };
    }
  ];
  pname = "gawk";
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable;
    packageMeta.upstream = import ./upstream.nix;
    source =
      { version, sha256 }:
      import <nix/fetchurl.nix> {
        url = "https://mirrors.kernel.org/gnu/gawk/gawk-${version}.${
          if version == "3.0.6" then
            "tar.gz"
          else if version == "3.1.8" then
            "tar.bz2"
          else
            "tar.xz"
        }";
        inherit sha256;
      };
    tests = import ./tests;
    testDeps = {
      inherit locale;
      checkLocales = import ./native/check-locales.nix {
        builder = tvp.builder;
        base = testBase;
        bash = testBase.shell;
        coreutils = testBase.coreutils;
        tar = testTools.gnutar;
        xz = testTools.xz;
        libc = testBase.compiler.libc;
      };
      localeProvider = testBase.compiler.libc;
    };
  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes.gawk = family;
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}

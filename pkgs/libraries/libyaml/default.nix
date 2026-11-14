{ pkgs, tvp }:
let
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build-0.0.1.nix;
        deps.file = tvp.packages.file;
        opts = {
          document = false;
          hasPkgConfig = false;
          sourceLayout = {
            selections = [
              "configure"
              "config/config.guess"
              "config/config.sub"
              "config/depcomp"
              "config/install-sh"
              "config/ltmain.sh"
              "config/missing"
            ];
            shellFragments = {
              "config/ltmain.sh" = [ "# ltmain.sh - Provide generalized library-building support services." ];
            };
            libtoolAnchors = {
              "config/ltmain.sh" = 1;
            };
          };
        };
      };
      releases = {
        "0.0.1" = "sha256-qPG0kQiY7s3GEdbApSfiJc6C/joDDzRO5pC4bAfG9S4=";
      };
    }
    {
      def = {
        builder = ./build-0.0.1.nix;
        deps.file = tvp.packages.file;
        opts = {
          hasPkgConfig = false;
          sourceLayout = {
            selections = [
              "configure"
              "config/config.guess"
              "config/config.sub"
              "config/depcomp"
              "config/install-sh"
              "config/ltmain.sh"
              "config/missing"
            ];
            shellFragments = {
              "config/ltmain.sh" = [
                "# ltmain.sh - Provide generalized library-building support services."
                "# Generated from ltmain.m4sh."
              ];
            };
            libtoolAnchors = {
              "config/ltmain.sh" = 1;
            };
          };
        };
      };
      releases = {
        "0.1.1" = "sha256-dkRGkqlN5OZ3ahvfO3NejwFrs3SufGBJb4Ay/cYIWIk=";
        "0.1.2" = "sha256-W+uUUpzHrHmxfjVPmwOuoxH1rxe+XUi8Oebx21BZ9w8=";
        "0.1.3" = "sha256-qLutflJQs3NRJrfjvZ9vzp2xnWvnzBOrrReiS1nsFEo=";
      };
    }
    {
      def = {
        builder = ./build-0.0.1.nix;
        deps.file = tvp.packages.file;
      };
      releases = {
        "0.1.4" = "sha256-e/gVVK5astm2l32jmOp4lyLg23W4a//a605m2WHeajc=";
        "0.1.5" = "sha256-+ofuj7e5NuwERXvARM1WEVXhAApNJQKYZ3UuVDwtO+8=";
        "0.1.6" = "sha256-faaXG0vQipht0qYTU7xCI2K9DtzGfX66rGjJX3QYJ0k=";
      };
    }
    {
      def = {
        builder = ./build-0.0.1.nix;
        deps.file = tvp.packages.file;
        opts.sourceLayout.selections = [
          "configure"
          "config/config.guess"
          "config/config.sub"
          "config/depcomp"
          "config/install-sh"
          "config/ltmain.sh"
          "config/missing"
          "config/compile"
        ];
      };
      releases = {
        "0.1.7" = "sha256-gIjkVyZKmLpFGpC4Zh/LT51vR49yZdSDIqGWzsJIByk=";
        "0.2.1" = "sha256-eCgRRWQaCA+zLW56h7nAZk1hHctNVC6Quvcx9Ry7Wc0=";
        "0.2.2" = "sha256-SpEAq2EEf9m9OVvO885UAzZcr9VcHg0Cmc3hSVjke+k=";
        "0.2.3" = "sha256-CLu4AoTXcJLmim9p8eSA6O2T4hXEeyyikpDjvVoZEQg=";
        "0.2.4" = "sha256-2ArtqHR7fCb7v9h6tod4blg5SoQ1rjlw55y5eILjBVc=";
        "0.2.5" = "sha256-xkKum3X+4SCy2WxxJTi9LPKDIo0jN98s8piOPAJnjvQ=";
      };
    }
  ];
  pname = "libyaml";
  retained = import ./retained { inherit pkgs tvp; };
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable;
    inherit (retained) packageMeta;
    source =
      { version, sha256 }:
      import <nix/fetchurl.nix> {
        url = "https://pyyaml.org/download/libyaml/yaml-${version}.tar.gz";
        inherit sha256;
      };
    tests = import ./tests;
    testDeps.pkgConfig = tvp.packages.pkg-config;
  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes.libyaml = family // {
    constructionRecipe = retained;
  };
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}

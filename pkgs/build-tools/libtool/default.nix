{ pkgs, tvp }:
let
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build-1.0.nix;
        deps = {
          autoconf = tvp.packages.autoconf_2;
          platformAutomake = tvp.packages.automake_1;
          automake = tvp.lib.packages.withConstraint {
            reason = "Libtool 1.0 cannot parse Automake 1.5 depcomp's .deps/answer.TPlo library-object argument; current 1.19 also fails on compile -o handling. Retain the independently qualified Automake 1.4 line for this consumer.";
          } tvp.packages.automake_1_4;
          m4 = tvp.packages.m4;
          file = tvp.packages.file;
        };
      };
      releases = {
        "1.0" = "sha256-89w7P05pCqRis340DsdQLnpdJl0UAqlcwCQPPVrqeiw=";
        "1.1" = "sha256-UsM9vsvUzcTl2Ki0DufHEB4iR8sttkoDqAMZKf4Sx68=";
        "1.2" = "sha256-HW1uP/Ai050M8t/b+Os73fNZKC6Ij1CP38FtlsJS+HU=";
      };
    }
    {
      def = {
        builder = ./build-1.3.5.nix;
        deps = {
          autoconf = tvp.packages.autoconf_2;
          platformAutomake = tvp.packages.automake_1;
          automake = tvp.packages.automake_1;
          m4 = tvp.packages.m4;
          file = tvp.packages.file;
        };
      };
      releases = {
        "1.3.5" = "sha256-AuKHumIaoB7lgbD4iFTesiL6Yefg/FXtdoUDg1TwJZ8=";
        "1.4.3" = "sha256-vR7b9k9XBHjvj2h1mslcxlPx2M+C7lSUiUd1E4t2VNc=";
      };
    }
    {
      def = {
        builder = ./build-1.5.26.nix;
        deps = {
          autoconf = tvp.packages.autoconf_2;
          automake = tvp.packages.automake_1;
          m4 = tvp.packages.m4;
          file = tvp.packages.file;
        };
      };
      releases = {
        "1.5.26" = "sha256-HDWuNP6FqhZ716tLyfR3/gGROOGvYmeNlS/EPAt+Lwk=";
      };
    }
    {
      def = {
        builder = ./build-2.2.10.nix;
        deps = {
          autoconf = tvp.packages.autoconf_2;
          automake = tvp.packages.automake_1;
          m4 = tvp.packages.m4;
          file = tvp.packages.file;
        };
      };
      releases = {
        "2.2.10" = "sha256-3n0dAo+jvhWgWz4A/mT4Ds5iY2kjzJ74Lci5ovPF130=";
      };
    }
    {
      def = {
        builder = ./build-2.4.7.nix;
        deps = {
          autoconf = tvp.packages.autoconf_2;
          automake = tvp.packages.automake_1;
          m4 = tvp.packages.m4;
          file = tvp.packages.file;
        };
        patches = [
          {
            file = ./patches/declared-tools.patch;
            reason = "Store-layout adaptation: bind declared Autoconf/Automake defaults while preserving upstream environment overrides.";
          }
        ];
      };
      releases = {
        "2.4.7" = "sha256-T38hfwV85lX/IlWa0iGg/Y74StH8X8tpkM7MMzqhY10=";
        "2.5.3" = "sha256-iYARIyzFm2s7u+Mhtgq6nbGsEVeKth7Q3wKZRYFGri4=";
        "2.5.4" = "sha256-+B9YYGZrC8fYS63e+mDRy5+m/OsjmMw7rKavqmAmZnU=";
      };
    }
    {
      def = {
        builder = ./build-2.4.7.nix;
        deps = {
          autoconf = tvp.packages.autoconf_2;
          automake = tvp.packages.automake_1;
          m4 = tvp.packages.m4;
          file = tvp.packages.file;
        };
        patches = [
          {
            file = ./patches/declared-tools.patch;
            reason = "Store-layout adaptation: bind declared Autoconf/Automake defaults while preserving upstream environment overrides.";
          }
        ];
        # One additional shipped template, without a different production procedure.
        opts.additionalTemplates = [ "libtool-next-version.in" ];
        # Preserve this release's existing complete upstream scope (older 2.x uses groups 1–10).
        opts.testGroups = [ ];
      };
      releases = {
        "2.6.2" = "sha256-LvEGfBbJfbkw/XQMybw9O6mlg4BK5axCzD6HGeSeGR4=";
      };
    }
  ];
  packageMeta.upstream = {
    type = "directory-index";
    url = "https://mirrors.kernel.org/gnu/libtool/";
    pattern = "libtool-[0-9][^\"]*\\.tar\\.(gz|xz)";
    normalise =
      file:
      let
        match = builtins.match "libtool-(.*)\\.tar\\.(gz|xz)" file;
      in
      if match == null then null else builtins.head match;
    include = version: builtins.match "[0-9]+(\\.[0-9]+)*" version != null;
  };
  pname = "libtool";
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable packageMeta;
    source =
      { version, sha256 }:
      import <nix/fetchurl.nix> {
        url = "https://mirrors.kernel.org/gnu/libtool/libtool-${version}.tar.${
          if builtins.compareVersions version "2.4.7" < 0 then "gz" else "xz"
        }";
        inherit sha256;
      };
    tests = import ./tests;
    testDeps = {
      runtimeShell = tvp.packages.bash_5;
      sentinel = (import ../../../bases/source-gnu/tests/probes.nix { }).sentinel;
      alternateSource = (import ../../../bootstrap/source-cmake-prerequisite-tests.nix { }).alternate;
    };
  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes.libtool = family // {
    constructionRecipe = (import ./legacy.nix { inherit pkgs tvp; }).recipes.libtool;
  };
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}

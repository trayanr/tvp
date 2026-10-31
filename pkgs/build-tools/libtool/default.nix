{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  base = tvp.bases.default;
  defs = tvpLib.packages.mkDefs {
    "1.0" = {
      builder = ./build-1.0.nix;
      inherit base;
      # Shipped configure and ltconfig probes use implicit-int main().
      opts.cStandard = "gnu89";
      opts = {
        testFeatures = {
          acLibtool = false;
          ltdl = false;
        };
        license = pkgs.lib.licenses.gpl2Plus;
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
      };
    };
    "1.3.5" = {
      builder = ./build-1.0.nix;
      inherit base;
      # Shipped configure and ltconfig probes use implicit-int main().
      opts.cStandard = "gnu89";
      deps = {
        autoconf = tvp.packages.autoconf_2;
        platformAutomake = tvp.packages.automake_1;
        automake = tvp.packages.automake_1;
        m4 = tvp.packages.m4;
        file = tvp.packages.file;
      };
    };
    "1.5.26" = {
      builder = ./build-1.5.26.nix;
      inherit base;
      deps = {
        autoconf = tvp.packages.autoconf_2;
        automake = tvp.packages.automake_1;
        m4 = tvp.packages.m4;
        file = tvp.packages.file;
      };
    };
    "2.2.10" = {
      builder = ./build-2.2.10.nix;
      inherit base;
      deps = {
        autoconf = tvp.packages.autoconf_2;
        automake = tvp.packages.automake_1;
        m4 = tvp.packages.m4;
        file = tvp.packages.file;
      };
    };
    "2.4.7" = {
      builder = ./build-2.4.7.nix;
      inherit base;
      deps = {
        autoconf = tvp.packages.autoconf_2;
        automake = tvp.packages.automake_1;
        m4 = tvp.packages.m4;
        file = tvp.packages.file;
      };
      patches = [
        {
          file = ./patches/declared-tools.patch;
          reason = "Store-layout adaptation: give libtoolize and generated libtool scripts declared Autoconf and Automake defaults while preserving upstream's environment overrides.";
        }
      ];
    };
  };
  versionTable = tvpLib.packages.mkTable [
    {
      def = defs."1.0";
      releases."1.0" = "sha256-89w7P05pCqRis340DsdQLnpdJl0UAqlcwCQPPVrqeiw=";
      releases."1.1" = "sha256-UsM9vsvUzcTl2Ki0DufHEB4iR8sttkoDqAMZKf4Sx68=";
      releases."1.2" = "sha256-HW1uP/Ai050M8t/b+Os73fNZKC6Ij1CP38FtlsJS+HU=";
    }
    {
      def = defs."1.3.5";
      releases."1.3.5" = "sha256-AuKHumIaoB7lgbD4iFTesiL6Yefg/FXtdoUDg1TwJZ8=";
      releases."1.4.3" = "sha256-vR7b9k9XBHjvj2h1mslcxlPx2M+C7lSUiUd1E4t2VNc=";
    }
    {
      def = defs."1.5.26";
      releases."1.5.26" = "sha256-HDWuNP6FqhZ716tLyfR3/gGROOGvYmeNlS/EPAt+Lwk=";
    }
    {
      def = defs."2.2.10";
      releases."2.2.10" = "sha256-3n0dAo+jvhWgWz4A/mT4Ds5iY2kjzJ74Lci5ovPF130=";
    }
    {
      def = defs."2.4.7";
      releases."2.4.7" = "sha256-T38hfwV85lX/IlWa0iGg/Y74StH8X8tpkM7MMzqhY10=";
      releases."2.5.3" = "sha256-iYARIyzFm2s7u+Mhtgq6nbGsEVeKth7Q3wKZRYFGri4=";
      releases."2.5.4" = "sha256-+B9YYGZrC8fYS63e+mDRy5+m/OsjmMw7rKavqmAmZnU=";
      releases."2.6.2" = "sha256-LvEGfBbJfbkw/XQMybw9O6mlg4BK5axCzD6HGeSeGR4=";
    }
  ];
  pname = "libtool";
  canonical = tvpLib.packages.mkVersions {
    infra = {
      inherit (pkgs) lib fetchurl;
    };
    inherit pname versionTable;
    extraArgs.mkTests = pkgs.lib.makeOverridable (
      { pkgs }: package: import ./tests { inherit pkgs tvpLib package; }
    ) { pkgs = tvpLib.tests.withBase { inherit pkgs base; }; };
    packageMeta.upstream = {
      type = "directory-index";
      url = "https://mirrors.kernel.org/gnu/libtool/";
      pattern = "libtool-[0-9][^\"]*\\.tar\\.gz";
      normalise =
        file:
        if pkgs.lib.hasPrefix "libtool-" file && pkgs.lib.hasSuffix ".tar.gz" file then
          pkgs.lib.removeSuffix ".tar.gz" (pkgs.lib.removePrefix "libtool-" file)
        else
          null;
      include = version: builtins.match "[0-9]+(\\.[0-9]+)*" version != null;
    };
  };
in
{
  inherit canonical;
  aliases = tvpLib.packages.mkAliases { inherit pname versionTable canonical; };
}

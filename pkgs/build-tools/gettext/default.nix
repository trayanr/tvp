{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  previous = import ./legacy.nix { inherit pkgs tvp; };
  constructionRecipe = previous.recipes.gettext;
  candidate = import ../../../bases/source-gnu { };
  native = pkgs.stdenv.hostPlatform.system == "x86_64-linux";
  defs = tvpLib.packages.mkDefs {
    "1.0" = {
      constructor = tvp.builder;
      builder = ./native/build-1.0.nix;
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
        inherit (tvp.packages)
          bash
          coreutils
          gnumake
          gnutar
          xz
          findutils
          diffutils
          gawk
          binutils
          patchelf
          ;
        sed = tvp.packages.gnused;
        grep = tvp.packages.gnugrep;
        pkg-config = tvp.packages.pkg-config;
        json-c = tvp.packages.json-c_0;
        curl = tvp.packages.curl;
        ncurses = tvp.packages.ncurses;
        libxml2 = tvp.packages.libxml2_2;
        acl = tvp.packages.acl;
        attr = tvp.packages.attr;
        perl = tvp.packages.perl_5;
        python = tvp.packages.python_3;
        jdk = tvp.packages.jdk_21;
      };
    };
  };
  versionTable = constructionRecipe.versionTable // {
    "1.0" = constructionRecipe.versionTable."1.0" // {
      def = if native then defs."1.0" else constructionRecipe.versionTable."1.0".def;
    };
  };
  publicArgs = constructionRecipe // {
    inherit versionTable;
    source =
      { version, sha256 }:
      pkgs.fetchurl {
        urls = [
          "https://mirrors.kernel.org/gnu/gettext/gettext-${version}.tar.xz"
          "https://ftp.gnu.org/gnu/gettext/gettext-${version}.tar.xz"
        ];
        inherit sha256;
      };
    testDeps = constructionRecipe.testDeps // {
      autoconf = tvp.packages.autoconf;
      automake = tvp.packages.automake;
      libtool = tvp.packages.libtool;
    };
    extraArgs.mkTests = pkgs.lib.makeOverridable (
      { pkgs }:
      package:
      if package ? testContext then
        import ./tests {
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
  pname = "gettext";
in
{
  recipes.${pname} = publicArgs // {
    inherit constructionRecipe;
  };
  inherit canonical;
  aliases = tvpLib.packages.mkAliases { inherit pname versionTable canonical; };
}

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
        # xml2-config --libs adds -lz to Gettext executables directly.
        zlib = tvp.packages.zlib_1;
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
  installedArgs = constructionRecipe // {
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
      # Ordinary latest tests follow the same public JDK as the owned procedure.
      jdk = tvp.packages.jdk_21;
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
  publicArgs = installedArgs // {
    extraArgs = installedArgs.extraArgs // {
      mkTests = pkgs.lib.makeOverridable (
        { pkgs }:
        package:
        (
          if installedArgs.extraArgs.mkTests ? override then
            (installedArgs.extraArgs.mkTests.override { inherit pkgs; }) package
          else
            installedArgs.extraArgs.mkTests package
        )
        // (import ../owned-split-tests.nix { inherit pkgs tvp package; })
      ) { inherit pkgs; };
    };
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

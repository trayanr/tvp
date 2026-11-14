{ pkgs, tvp }:
let
  previous = import ./retained-index.nix { inherit pkgs tvp; };
  prior = previous.recipes."gettext";
  retained = prior.constructionRecipe or prior;
  earlier = import ../../../bases/source-gnu { };
  full = tvp.baseTiers.full;
  profileBase = full.override {
    shell = tvp.packages.bash;
    coreutils = tvp.packages.coreutils;
    standardTools = {
      gnumake = tvp.packages.gnumake;
      gnutar = tvp.packages.gnutar;
      xz = tvp.packages.xz;
      findutils = tvp.packages.findutils;
      diffutils = tvp.packages.diffutils;
      gawk = tvp.packages.gawk;
      patchelf = tvp.packages.patchelf;
      sed = tvp.packages.gnused;
      grep = tvp.packages.gnugrep;
      pkg-config = tvp.packages.pkg-config;
    };
  };
  pname = "gettext";
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build-1.0-current.nix;
        base = profileBase;
        deps = {
          binutils = tvp.packages.binutils;
          json-c = tvp.packages.json-c_0;
          curl = tvp.packages.curl;
          ncurses = tvp.packages.ncurses;
          libxml2 = tvp.packages.libxml2_2;
          zlib = tvp.packages.zlib_1;
          acl = tvp.packages.acl;
          attr = tvp.packages.attr;
          perl = tvp.packages.perl_5;
          python = tvp.packages.python_3;
          jdk = tvp.packages.jdk_21;
        };
      };
      releases = {
        "1.0" = "sha256-cRMqP7ceaCRbjyrE6elxN9PlwC9BVjbrUIrmB7wBrdc=";
      };
    }
  ];
  testDeps = (prior.testDeps or { }) // {
    jdk = tvp.packages.jdk_21;
    autoconf = tvp.packages.autoconf;
    automake = tvp.packages.automake;
    libtool = tvp.packages.libtool;
  };
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable testDeps;
    packageMeta = prior.packageMeta or { };
    source =
      { version, sha256 }:
      pkgs.fetchurl {
        urls = [
          "https://mirrors.kernel.org/gnu/gettext/gettext-${version}.tar.xz"
          "https://ftp.gnu.org/gnu/gettext/gettext-${version}.tar.xz"
        ];
        inherit sha256;
      };
    tests = import ./tests;
  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes."gettext" = family // {
    constructionRecipe = retained;
  };
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}

{ pkgs, tvp }:
let
  pname = "gettext";
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build-1.0-current.nix;
        deps = {

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
  testDeps = {
    python = tvp.packages.python_3;
    jdk = tvp.packages.jdk_21;
    autoconf = tvp.packages.autoconf;
    automake = tvp.packages.automake;
    libtool = tvp.packages.libtool;
  };
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable testDeps;

    source = tvp.lib.sources.archive {
      url = version: "https://mirrors.kernel.org/gnu/gettext/gettext-${version}.tar.xz";
      fetch =
        { version, sha256 }:
        pkgs.fetchurl {
          urls = [
            "https://mirrors.kernel.org/gnu/gettext/gettext-${version}.tar.xz"
            "https://ftp.gnu.org/gnu/gettext/gettext-${version}.tar.xz"
          ];
          inherit sha256;
        };
      discovery = {
        type = "directory-index";
        url = "https://ftp.gnu.org/gnu/gettext/";
        pattern = "gettext-[0-9]+(\\.[0-9]+)*\\.tar\\.(gz|xz|lz)";
        normalise =
          file:
          let
            m = builtins.match "gettext-([0-9]+(\\.[0-9]+)*)\\.tar\\.(gz|xz|lz)" file;
          in
          if m == null then null else builtins.head m;
      };
    };
    tests = import ./tests;
  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes."gettext" = family;
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}

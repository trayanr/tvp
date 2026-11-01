{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  pname = "gettext";
  defs = tvpLib.packages.mkDefs {
    "1.0" = {
      builder = ./build-1.0.nix;
      base = tvp.bases.default;
      deps = {
        bash = tvp.packages.bash;
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
  versionTable = tvpLib.packages.mkTable [
    {
      def = defs."1.0";
      releases."1.0" = "sha256-cRMqP7ceaCRbjyrE6elxN9PlwC9BVjbrUIrmB7wBrdc=";
    }
  ];
  packageArgs = {
    inherit pname versionTable;
    infra = {
      inherit (pkgs) lib fetchurl;
    };
    testDeps = {
      jdk = tvp.packages.jdk_21;
      python = tvp.packages.python_3;
    };
    extraArgs.mkTests =
      package:
      import ./tests {
        inherit tvpLib package;
        inherit (package.tvp.declaredTestDependencies) python jdk;
        pkgs = tvpLib.tests.withBase {
          inherit pkgs;
          base.stdenv = package.stdenv;
        };
      };
    packageMeta.upstream = {
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
  canonical = tvpLib.packages.mkVersions packageArgs;
in
{
  recipes.${pname} = packageArgs;
  inherit canonical;
  aliases = tvpLib.packages.mkAliases { inherit pname versionTable canonical; };
}

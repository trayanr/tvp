{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  defs = tvpLib.packages.mkDefs {
    "2.56.0" = {
      builder = ./build-2.56.0.nix;
      base = tvp.bases.default;
      deps = {
        rustc = tvp.packages.rustc_1;
        cargo = tvp.packages.cargo-bootstrap_1;
        pkg-config = tvp.packages.pkg-config;
        patchelf = tvp.packages.patchelf;
        bash = tvp.packages.bash_5;
        perl = tvp.packages.perl_5;
        python = tvp.packages.python_3;
        curl = tvp.packages.curl_8;
        openssl = tvp.packages.openssl;
        zlib = tvp.packages.zlib_1;
        expat = tvp.packages.expat_2;
        pcre2 = tvp.packages.pcre2_10;
      };
    };
  };
  pname = "git";
  versionTable = tvpLib.packages.mkTable [
    {
      def = defs."2.56.0";
      releases."2.56.0" = "sha256-JsVsKWs4wGlbJvqV9HXx0BcE0tOOc0ZcowsLL13HidM=";
    }
  ];
  canonical = tvpLib.packages.mkVersions {
    infra = {
      inherit (pkgs) lib fetchurl;
    };
    inherit pname versionTable;
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
in
{
  inherit canonical;
  aliases = tvpLib.packages.mkAliases { inherit pname versionTable canonical; };
}

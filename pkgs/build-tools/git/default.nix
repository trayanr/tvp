{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  defs = tvpLib.packages.mkDefs {
    "2.56.0" = {
      builder = ./build-2.56.0.nix;
      base = tvp.bases.default;
      deps = {
        rustc = tvp.packages.rustc_1_97_1;
        cargo = tvp.packages.cargo-bootstrap_1_97_1;
        pkg-config = tvp.packages.pkg-config_0_29_2;
        patchelf = tvp.packages.patchelf_0_19_2;
        bash = tvp.packages.bash_5_2_37;
        perl = tvp.packages.perl_5_44_0;
        python = tvp.packages.python_3_12_16;
        curl = tvp.packages.curl_8_23_0;
        openssl = tvp.packages.openssl_3_6_3;
        zlib = tvp.packages.zlib_1_3_2;
        expat = tvp.packages.expat_2_9_0;
        pcre2 = tvp.packages.pcre2_10_44;
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

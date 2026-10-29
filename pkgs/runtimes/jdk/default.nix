{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  platform = tvpLib.platforms.forStdenv tvp.bases.default.stdenv;
  defs = tvpLib.packages.mkDefs {
    "21.0.13" = {
      builder = ./build-21.0.13.nix;
      base = tvp.bases.default;
      deps = {
        xorgproto = tvp.packages.xorgproto_2026_1;
        libx11 = tvp.packages.libx11_1_8_14;
        libxext = tvp.packages.libxext_1_3_7;
        libxrender = tvp.packages.libxrender_0_9_13;
        libxtst = tvp.packages.libxtst_1_2_6;
        libxrandr = tvp.packages.libxrandr_1_5_5;
        libxt = tvp.packages.libxt_1_3_1;
        bootJdk = tvp.packages.jdk-bootstrap_21_0_13;
        bash = tvp.packages.bash_5_2_37;
        autoconf = tvp.packages.autoconf_2_73;
        zip = tvp.packages.zip_3_0;
        unzip = tvp.packages.unzip_6_0;
        file = tvp.packages.file_5_45;
        pkg-config = tvp.packages.pkg-config_0_29_2;
        patchelf = tvp.packages.patchelf_0_19_2;
        zlib = tvp.packages.zlib_1_3_2;
        alsa = tvp.packages.alsa-lib_1_2_16_1;
        freetype = tvp.packages.freetype_2_15_0;
        fontconfig = tvp.packages.fontconfig_2_18_3;
        libcups = tvp.packages.libcups_2_4_20;
      };
      opts = {
        inherit (platform) dynamicLinker;
        buildNumber = "9";
      };
      patches = [
        {
          file = ./patches/store-paths.patch;
          reason = "Use the declared store shell for executable-script fallback, including libc execvp fast paths which otherwise force /bin/sh; select the owned Fontconfig library for runtime font discovery.";
        }
      ];
    };
  };
  pname = "jdk";
  versionTable = tvpLib.packages.mkTable [
    {
      def = defs."21.0.13";
      releases."21.0.13" = "sha256-oQ63VvElQrUw25DhWv9ExyzVcroCxHSWr/teNRCBSTU=";
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

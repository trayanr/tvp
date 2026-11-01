{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  platform = tvpLib.platforms.forStdenv tvp.bases.default.stdenv;
  defs = tvpLib.packages.mkDefs {
    "21.0.13" = {
      builder = ./build-21.0.13.nix;
      base = tvp.bases.default;
      deps = {
        xorgproto = tvp.packages.xorgproto;
        libx11 = tvp.packages.libx11_1;
        libxext = tvp.packages.libxext_1;
        libxrender = tvp.packages.libxrender;
        libxtst = tvp.packages.libxtst_1;
        libxrandr = tvp.packages.libxrandr_1;
        libxt = tvp.packages.libxt_1;
        bootJdk = (
          tvp.lib.packages.withConstraint {
            category = "construction";
            reason = "Explicit upstream bootstrap stage; preserve the released compiler seed and acyclic construction chain.";
          } tvp.canonical."jdk-bootstrap_21_0_13"
        );
        bash = tvp.packages.bash_5;
        autoconf = tvp.packages.autoconf_2;
        zip = tvp.packages.zip;
        unzip = tvp.packages.unzip;
        file = tvp.packages.file;
        pkg-config = tvp.packages.pkg-config;
        patchelf = tvp.packages.patchelf;
        zlib = tvp.packages.zlib_1;
        alsa = tvp.packages.alsa-lib_1;
        freetype = tvp.packages.freetype_2;
        fontconfig = tvp.packages.fontconfig_2;
        libcups = tvp.packages.libcups_2;
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
  packageArgs = {
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
  canonical = tvpLib.packages.mkVersions packageArgs;

in
{
  inherit canonical;
  aliases = tvpLib.packages.mkAliases { inherit pname versionTable canonical; };
}

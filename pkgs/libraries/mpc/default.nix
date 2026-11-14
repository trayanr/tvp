{ pkgs, tvp }:
let
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build-1.0.3.nix;
        archiveExtension = "tar.gz";
        deps = {
          gmp = tvp.packages.gmp_6;
          mpfr = tvp.lib.packages.withConstraint {
            reason = "MPC 1.0.3 mul.c defines its own seven-argument mpfr_fmma; MPFR 4 adds a six-argument public function with that name. Native compilation fails with 4.2.2; use the working MPFR 3 line.";
          } tvp.packages.mpfr_3;
        };
        opts.additionalSourceScripts = [ "compile" ];
      };
      releases."1.0.3" = "sha256-YX3sxuoJiJ+wjt4zCRegCxaAm424jCnDG/u0nL+I7MM=";
    }
    {
      def = {
        builder = ./build-1.0.3.nix;
        archiveExtension = "tar.gz";
        deps = {
          gmp = tvp.packages.gmp_6;
          mpfr = tvp.packages.mpfr_4;
        };
      };
      releases."1.1.0" = "sha256-aYXFOBQ8EgjcsaxCztrW/1LiZ7R+X5cBg6PnUSW0PC4=";
    }
    {
      def = {
        builder = ./build-1.2.0.nix;
        archiveExtension = "tar.gz";
        deps = {
          gmp = tvp.packages.gmp_6;
          mpfr = tvp.packages.mpfr_4;
        };
      };
      releases = {
        "1.2.0" = "sha256-6Q8tmVU6nBmRGr20MFv4IXEGqVfjmUQ2QoVyyN/o/aY=";
        "1.2.1" = "sha256-F1A9LDld/PEGtiLcFCaDwRmUMdCVNnxqrLpu7DA0BFk=";
        "1.3.0" = "sha256-DjsSGB03IHIw9aen3c/CKr/F/JwFgl4aZUAaSJpDKio=";
        "1.3.1" = "sha256-q2QkkvXPiCt0qgy3MM1BCoHtzb7IlRg86TDnBsHHWbg=";
      };
    }
    {
      def = {
        builder = ./build-1.4.0.nix;
        archiveExtension = "tar.xz";
        deps = {
          gmp = tvp.packages.gmp_6;
          mpfr = tvp.packages.mpfr_4;
        };
      };
      releases = {
        "1.4.0" = "sha256-MhCzpUaxywDClso2CJHXdA7m/wbesCono1sgzTwLsaU=";
        "1.4.1" = "sha256-kSBM0y8WS9O3yZLUpqjOZRlRGq2rMPeLaYLQv41z6TE=";
      };
    }
  ];
  packageMeta.upstream = {
    type = "directory-index";
    url = "https://mirrors.kernel.org/gnu/mpc/";
    pattern = "mpc-[0-9][^\"]*\\.tar\\.(gz|xz)";
    normalise =
      file:
      let
        match = builtins.match "mpc-([0-9]+(\\.[0-9]+)*)\\.tar\\.(gz|xz)" file;
      in
      if match == null then null else builtins.head match;
    include = version: builtins.match "[0-9]+(\\.[0-9]+)*" version != null;
  };
  pname = "mpc";
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable packageMeta;
    source =
      { version, sha256 }:
      import <nix/fetchurl.nix> {
        url = "https://mirrors.kernel.org/gnu/mpc/mpc-${version}.${
          versionTable.${version}.def.archiveExtension
        }";
        inherit sha256;
      };
    tests = import ./tests;
  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes.mpc = family // {
    constructionRecipe = import ./retained {
      inherit
        pkgs
        tvp
        versionTable
        packageMeta
        ;
    };
  };
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}

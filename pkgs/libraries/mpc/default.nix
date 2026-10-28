{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  defs = tvpLib.packages.mkDefs {
    "1.0.3" = {
      builder = ./build-1.0.3.nix;
      base = tvp.bases.default;
      deps = {
        gmp = tvp.packages.gmp_6_3_0;
        mpfr = tvp.packages.mpfr_3_1_6;
      };
    };
    "1.1.0" = {
      builder = ./build-1.0.3.nix;
      base = tvp.bases.default;
      deps = {
        gmp = tvp.packages.gmp_6_3_0;
        mpfr = tvp.packages.mpfr_4_2_1;
      };
    };
    "1.4.1" = {
      builder = ./build-1.0.3.nix;
      base = tvp.bases.default;
      deps = {
        gmp = tvp.packages.gmp_6_3_0;
        mpfr = tvp.packages.mpfr_4_2_2;
      };
      opts.archiveExt = "tar.xz";
    };
  };
  versionTable = tvpLib.packages.mkTable [
    {
      def = defs."1.0.3";
      releases = {
        "1.0.3" = "sha256-YX3sxuoJiJ+wjt4zCRegCxaAm424jCnDG/u0nL+I7MM=";
      };
    }
    {
      def = defs."1.1.0";
      releases = {
        "1.1.0" = "sha256-aYXFOBQ8EgjcsaxCztrW/1LiZ7R+X5cBg6PnUSW0PC4=";
        "1.2.1" = "sha256-F1A9LDld/PEGtiLcFCaDwRmUMdCVNnxqrLpu7DA0BFk=";
        "1.3.1" = "sha256-q2QkkvXPiCt0qgy3MM1BCoHtzb7IlRg86TDnBsHHWbg=";
      };
    }
    {
      def = defs."1.4.1";
      releases = {
        "1.4.1" = "sha256-kSBM0y8WS9O3yZLUpqjOZRlRGq2rMPeLaYLQv41z6TE=";
      };
    }
  ];
  pname = "mpc";
  packageArgs = {
    infra = {
      inherit (pkgs) lib fetchurl;
    };
    inherit pname versionTable;
    extraArgs.mkTests = pkgs.lib.makeOverridable (
      { pkgs }:
      mpc:
      import ./tests {
        inherit tvpLib mpc;
        pkgs = tvpLib.tests.withBase {
          inherit pkgs;
          base.stdenv = mpc.stdenv;
        };
      }
    ) { inherit pkgs; };
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
  };
  canonical = tvpLib.packages.mkVersions packageArgs;
  variants = tvpLib.packages.mkVariants (
    packageArgs
    // {
      inherit pkgs;
      profiles.gcc13 = {
        base = tvp.bases.gcc13;
        versions."1.3.1" = {
          deps = {
            gmp = tvp.variants.gcc13.gmp_6_3_0;
            mpfr = tvp.variants.gcc13.mpfr_4_2_1;
          };
        };
      };
    }
  );

in
{
  inherit canonical variants;
  aliases = tvpLib.packages.mkAliases { inherit pname versionTable canonical; };
}

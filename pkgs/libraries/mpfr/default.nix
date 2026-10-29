{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  defs = tvpLib.packages.mkDefs {
    "2.4.2" = {
      builder = ./build-2.4.2.nix;
      base = tvp.bases.default;
      deps.gmp = tvp.packages.gmp_5_0_5;
      opts.float128 = false;
      opts.mpfrRoundingNames = false;
    };
    "3.0.1" = {
      builder = ./build-2.4.2.nix;
      base = tvp.bases.default;
      deps.gmp = tvp.packages.gmp_5_0_5;
      opts.float128 = false;
    };
    "3.1.6" = {
      builder = ./build-2.4.2.nix;
      base = tvp.bases.default;
      deps.gmp = tvp.packages.gmp_6_3_0;
      opts.float128 = false;
    };
    "4.0.2" = {
      builder = ./build-2.4.2.nix;
      base = tvp.bases.default;
      deps.gmp = tvp.packages.gmp_6_3_0;
    };
  };
  versionTable = tvpLib.packages.mkTable [
    {
      def = defs."2.4.2";
      releases = {
        "2.4.2" = "sha256-1ycbv7yd3zh9ORnfgxjNcZLGeyMpGb+hyzIC0HhD2hs=";
      };
    }
    {
      def = defs."3.0.1";
      releases = {
        "3.0.1" = "sha256-KKltWPJ2NSipebKgFpWdziq7yP74FC+hhgZwwkh2AGE=";
      };
    }
    {
      def = defs."3.1.6";
      releases = {
        "3.1.6" = "sha256-emKsGgRAhhT8zcUG5IRLEM8K0sKxZ3CX+PNdOhNEqVA=";
      };
    }
    {
      def = defs."4.0.2";
      releases = {
        "4.0.2" = "sha256-HTvnCGBOrg5C1Xi6k7OQwqFF8XdDp0TY8/jCrVhVo4o=";
        "4.1.1" = "sha256-/9GVvVZ9uv/DuYsj/QCq0FN2gMmJYXHkT+P/eeKKwz0=";
        "4.2.1" = "sha256-J3gHNTpnJpeJlpRa8T5Sgp46vXqaW3+yeTiU4Y8fy7I=";
        "4.2.2" = "sha256-tnugOD736KhWNzTi6InvXsPDuJigHQD6CmhprYHGzgE=";
      };
    }
  ];
  pname = "mpfr";
  packageArgs = {
    infra = {
      inherit (pkgs) lib fetchurl;
    };
    inherit pname versionTable;
    extraArgs.mkTests = pkgs.lib.makeOverridable (
      { pkgs }:
      mpfr:
      import ./tests {
        inherit tvpLib mpfr;
        pkgs = tvpLib.tests.withBase {
          inherit pkgs;
          base.stdenv = mpfr.stdenv;
        };
      }
    ) { inherit pkgs; };
    packageMeta.upstream = {
      type = "directory-index";
      url = "https://mirrors.kernel.org/gnu/mpfr/";
      pattern = "mpfr-[0-9][^\"]*\\.tar\\.(gz|bz2|xz)";
      normalise =
        file:
        let
          match = builtins.match "mpfr-([0-9]+(\\.[0-9]+)*)\\.tar\\.(gz|bz2|xz)" file;
        in
        if match == null then null else builtins.head match;
      include = version: builtins.match "[0-9]+(\\.[0-9]+)*" version != null;
    };
  };
  canonical = tvpLib.packages.mkVersions packageArgs;

in
{
  recipes.${pname} = packageArgs;
  inherit canonical;
  aliases = tvpLib.packages.mkAliases { inherit pname versionTable canonical; };
}

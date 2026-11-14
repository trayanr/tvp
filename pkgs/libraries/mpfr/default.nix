{ tvp, ... }:
let
  packageRecipes = tvp.lib.packages.mkDefs {
    "2.4.2" = {
      builder = ./build-2.4.2.nix;
      deps.gmp = tvp.lib.packages.withConstraint {
        reason = "MPFR 2.4.2/3.0.1 headers use __gmp_const, removed by GMP 5.1; use the compatible GMP 5.0 line.";
      } tvp.packages.gmp_5_0;
      opts.installedInterface = {
        sonameMajor = "1";
        mpfrRoundingNames = false;
      };
    };
    "3.0.1" = {
      builder = ./build-2.4.2.nix;
      deps.gmp = tvp.lib.packages.withConstraint {
        reason = "MPFR 2.4.2/3.0.1 headers use __gmp_const, removed by GMP 5.1; use the compatible GMP 5.0 line.";
      } tvp.packages.gmp_5_0;
    };
    "3.1.6" = {
      builder = ./build-2.4.2.nix;
      deps.gmp = tvp.packages.gmp_6;
      opts.additionalSourceScripts = [ "test-driver" ];
    };
    "4.0.2" = {
      builder = ./build-4.0.2.nix;
      deps.gmp = tvp.packages.gmp_6;
      opts.checkCFlags = [ "-std=gnu17" ];
    };
    "4.2.1" = {
      builder = ./build-4.0.2.nix;
      deps.gmp = tvp.packages.gmp_6;
    };
  };
  versionTable = tvp.lib.packages.mkTable [
    {
      def = packageRecipes."2.4.2";
      releases = {
        "2.4.2" = "sha256-1ycbv7yd3zh9ORnfgxjNcZLGeyMpGb+hyzIC0HhD2hs=";
      };
    }
    {
      def = packageRecipes."3.0.1";
      releases = {
        "3.0.1" = "sha256-KKltWPJ2NSipebKgFpWdziq7yP74FC+hhgZwwkh2AGE=";
      };
    }
    {
      def = packageRecipes."3.1.6";
      releases = {
        "3.1.6" = "sha256-emKsGgRAhhT8zcUG5IRLEM8K0sKxZ3CX+PNdOhNEqVA=";
      };
    }
    {
      def = packageRecipes."4.0.2";
      releases = {
        "4.0.2" = "sha256-HTvnCGBOrg5C1Xi6k7OQwqFF8XdDp0TY8/jCrVhVo4o=";
        "4.1.0" = "sha256-DJij8XMv9spOppBVIHnanFl4ctMOluwoQU7iPJVVin8=";
        "4.1.1" = "sha256-/9GVvVZ9uv/DuYsj/QCq0FN2gMmJYXHkT+P/eeKKwz0=";
        "4.2.0" = "sha256-BqN43xNQEkjBsttaqXeiyBJq6Emp2be+JUb7Spwm2ZM=";
      };
    }
    {
      def = packageRecipes."4.2.1";
      releases = {
        "4.2.1" = "sha256-J3gHNTpnJpeJlpRa8T5Sgp46vXqaW3+yeTiU4Y8fy7I=";
        "4.2.2" = "sha256-tnugOD736KhWNzTi6InvXsPDuJigHQD6CmhprYHGzgE=";
      };
    }
  ];
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
  pname = "mpfr";
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable packageMeta;
    source =
      { version, sha256 }:
      import <nix/fetchurl.nix> {
        url = "https://mirrors.kernel.org/gnu/mpfr/mpfr-${version}.tar.xz";
        inherit sha256;
      };
    tests = import ./tests;
  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes.mpfr = family;
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}

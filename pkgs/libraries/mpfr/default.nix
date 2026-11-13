{ tvp, ... }:
let
  tvpLib = tvp.lib;
  defs = tvpLib.packages.mkDefs {
    "2.4.2" = {
      builder = ./build.nix;
      deps.gmp = tvpLib.packages.withConstraint {
        reason = "MPFR 2.4.2/3.0.1 headers use __gmp_const, removed by GMP 5.1; use the compatible GMP 5.0 line.";
      } tvp.packages.gmp_5_0;
      opts = {
        checkCFlags = [ "-std=gnu17" ];
        float128 = false;
        mpfrRoundingNames = false;
        hasPkgConfig = false;
        sonameMajor = "1";
        sourceScripts = [
          "configure"
          "config.guess"
          "config.sub"
          "install-sh"
          "ltmain.sh"
          "missing"
          "depcomp"
          "compile"
        ];
      };
    };
    "3.0.1" = {
      builder = ./build.nix;
      deps.gmp = tvpLib.packages.withConstraint {
        reason = "MPFR 2.4.2/3.0.1 headers use __gmp_const, removed by GMP 5.1; use the compatible GMP 5.0 line.";
      } tvp.packages.gmp_5_0;
      opts = {
        checkCFlags = [ "-std=gnu17" ];
        float128 = false;
        hasPkgConfig = false;
        sonameMajor = "4";
        sourceScripts = [
          "configure"
          "config.guess"
          "config.sub"
          "install-sh"
          "ltmain.sh"
          "missing"
          "depcomp"
          "compile"
        ];
      };
    };
    "3.1.6" = {
      builder = ./build.nix;
      deps.gmp = tvp.packages.gmp_6;
      opts = {
        checkCFlags = [ "-std=gnu17" ];
        float128 = false;
        hasPkgConfig = false;
        sonameMajor = "4";
        sourceScripts = [
          "configure"
          "config.guess"
          "config.sub"
          "install-sh"
          "ltmain.sh"
          "missing"
          "depcomp"
          "compile"
          "test-driver"
        ];
      };
    };
    "4.0.2" = {
      builder = ./build.nix;
      deps.gmp = tvp.packages.gmp_6;
      opts.checkCFlags = [ "-std=gnu17" ];
    };
    "4.2.1" = {
      builder = ./build.nix;
      deps.gmp = tvp.packages.gmp_6;
    };
    "4.2.2" = {
      builder = ./build.nix;
      deps.gmp = tvp.packages.gmp_6;
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
        "4.1.0" = "sha256-DJij8XMv9spOppBVIHnanFl4ctMOluwoQU7iPJVVin8=";
        "4.1.1" = "sha256-/9GVvVZ9uv/DuYsj/QCq0FN2gMmJYXHkT+P/eeKKwz0=";
        "4.2.0" = "sha256-BqN43xNQEkjBsttaqXeiyBJq6Emp2be+JUb7Spwm2ZM=";
      };
    }
    {
      def = defs."4.2.1";
      releases = {
        "4.2.1" = "sha256-J3gHNTpnJpeJlpRa8T5Sgp46vXqaW3+yeTiU4Y8fy7I=";
      };
    }
    {
      def = defs."4.2.2";
      releases."4.2.2" = "sha256-tnugOD736KhWNzTi6InvXsPDuJigHQD6CmhprYHGzgE=";
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
  family = tvpLib.packages.mkFamily {
    inherit pname versionTable packageMeta;
    source =
      { version, sha256 }:
      import <nix/fetchurl.nix> {
        url = "https://mirrors.kernel.org/gnu/mpfr/mpfr-${version}.tar.xz";
        inherit sha256;
      };
    tests = import ./tests;
  };
  canonical = tvpLib.packages.mkVersions family;
in
{
  recipes.mpfr = family;
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvpLib.packages.mkAliases { inherit pname versionTable canonical; };
}

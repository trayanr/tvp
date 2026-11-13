{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  defs = {
    "2.4.2" = {
      builder = ./ordinary/build-2.4.2.nix;
      deps = {
        inherit (tvp.packages)
          gnumake
          gnutar
          xz
          diffutils
          findutils
          ;
        python = tvp.packages.python-build_3_12_5;
        patchelf = tvp.packages.patchelf_0;
        sed = tvp.packages.gnused;
        grep = tvp.packages.gnugrep;
        gawk = tvpLib.packages.withConstraint {
          reason = "MPFR needs AWK to configure; the public Gawk 5 line depends on MPFR. The Gawk 4.0 line has no MPFR dependency.";
        } tvp.packages.gawk_4_0;
        gmp = tvpLib.packages.withConstraint {
          reason = "MPFR 2.4.2/3.0.1 public headers use __gmp_const, removed by GMP 5.1. Native compilation fails with newer GMP; 5.0.5 is the working control, selected through the moving 5.0 line.";
        } tvp.packages.gmp_5_0;
      };
      opts = {
        checkCFlags = [ "-std=gnu17" ];
        float128 = false;
        mpfrRoundingNames = false;
      };
    };
    "3.0.1" = {
      builder = ./ordinary/build-2.4.2.nix;
      deps = {
        inherit (tvp.packages)
          gnumake
          gnutar
          xz
          diffutils
          findutils
          ;
        python = tvp.packages.python-build_3_12_5;
        patchelf = tvp.packages.patchelf_0;
        sed = tvp.packages.gnused;
        grep = tvp.packages.gnugrep;
        gawk = tvpLib.packages.withConstraint {
          reason = "MPFR needs AWK to configure; the public Gawk 5 line depends on MPFR. The Gawk 4.0 line has no MPFR dependency.";
        } tvp.packages.gawk_4_0;
        gmp = tvpLib.packages.withConstraint {
          reason = "MPFR 2.4.2/3.0.1 public headers use __gmp_const, removed by GMP 5.1. Native compilation fails with newer GMP; 5.0.5 is the working control, selected through the moving 5.0 line.";
        } tvp.packages.gmp_5_0;
      };
      opts = {
        checkCFlags = [ "-std=gnu17" ];
        float128 = false;
      };
    };
    "3.1.6" = {
      builder = ./ordinary/build-2.4.2.nix;
      deps = {
        inherit (tvp.packages)
          gnumake
          gnutar
          xz
          diffutils
          findutils
          ;
        python = tvp.packages.python-build_3_12_5;
        patchelf = tvp.packages.patchelf_0;
        sed = tvp.packages.gnused;
        grep = tvp.packages.gnugrep;
        gawk = tvpLib.packages.withConstraint {
          reason = "MPFR needs AWK to configure; the public Gawk 5 line depends on MPFR. The Gawk 4.0 line has no MPFR dependency.";
        } tvp.packages.gawk_4_0;
        gmp = tvp.packages.gmp_6;
      };
      opts = {
        checkCFlags = [ "-std=gnu17" ];
        float128 = false;
      };
    };
    "4.0.2" = {
      builder = ./ordinary/build-4.0.2.nix;
      deps = {
        inherit (tvp.packages)
          gnumake
          gnutar
          xz
          diffutils
          findutils
          ;
        python = tvp.packages.python-build_3_12_5;
        patchelf = tvp.packages.patchelf_0;
        sed = tvp.packages.gnused;
        grep = tvp.packages.gnugrep;
        gawk = tvpLib.packages.withConstraint {
          reason = "MPFR needs AWK to configure; the public Gawk 5 line depends on MPFR. The Gawk 4.0 line has no MPFR dependency.";
        } tvp.packages.gawk_4_0;
        gmp = tvp.packages.gmp_6;
      };
    };
    "4.2.1" = {
      builder = ./ordinary/build-4.2.1.nix;
      deps = {
        inherit (tvp.packages)
          gnumake
          gnutar
          xz
          diffutils
          findutils
          ;
        python = tvp.packages.python-build_3_12_5;
        patchelf = tvp.packages.patchelf_0;
        sed = tvp.packages.gnused;
        grep = tvp.packages.gnugrep;
        gawk = tvpLib.packages.withConstraint {
          reason = "MPFR needs AWK to configure; the public Gawk 5 line depends on MPFR. The Gawk 4.0 line has no MPFR dependency.";
        } tvp.packages.gawk_4_0;
        gmp = tvp.packages.gmp_6;
      };
    };
    "4.2.2" = {
      builder = ./build-4.2.2.nix;
      deps = {
        inherit (tvp.packages)
          gnumake
          gnutar
          xz
          diffutils
          findutils
          ;
        python = tvp.packages.python-build_3_12_5;
        patchelf = tvp.packages.patchelf_0;
        sed = tvp.packages.gnused;
        grep = tvp.packages.gnugrep;
        gawk = tvpLib.packages.withConstraint {
          reason = "MPFR needs AWK to configure; the public Gawk 5 line depends on MPFR. The Gawk 4.0 line has no MPFR dependency.";
        } tvp.packages.gawk_4_0;
        gmp = tvp.packages.gmp_6;
      };
    };
  };
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
  family = tvpLib.packages.mkFamily {
    pname = "mpfr";
    inherit defs packageMeta;
    releases = import ./releases.nix;
    source =
      { version, sha256 }:
      import <nix/fetchurl.nix> {
        url = "https://mirrors.kernel.org/gnu/mpfr/mpfr-${version}.tar.xz";
        inherit sha256;
      };
    tests = import ./tests/family.nix;
  };
  retained = import ./retained.nix { inherit pkgs tvp packageMeta; };
in
family
// {
  recipes.mpfr = family.recipes.mpfr // {
    inherit (retained) constructionRecipe;
  };
  variants.build-steps = import ./variants.nix {
    inherit pkgs tvp;
    family = retained.publicFallback;
  };
}

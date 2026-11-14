{ pkgs, tvp }:
let
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build-3.0.5.nix;
        deps = {
          m4 = tvp.packages.m4;
          perl = tvp.packages.perl_5;
        };
        opts.preserveCharsetPrefix = true;
      };
      releases = {
        "3.0.5" = "sha256-zTmdK+4zr6cSusSx9ENOIDeem0CZvORxieCadnWi1WY=";
      };
    }
    {
      def = {
        builder = ./build-3.0.5.nix;
        deps = {
          m4 = tvp.packages.m4;
          perl = tvp.packages.perl_5;
        };
      };
      releases = {
        "3.1" = "sha256-p8s2tVMW7uxiaGXAPSpEIQYXoXx9OT7mPYVT4GSe6UY=";
        "3.2.4" = "sha256-y2c+IpjTS15Gun3wZBr6c02hRXzkfeSRhjQHpYfux5o=";
      };
    }
    {
      def = {
        builder = ./build-3.3.2.nix;
        deps = {
          m4 = tvp.packages.m4;
          perl = tvp.packages.perl_5;
        };
      };
      releases = {
        "3.3.2" = "sha256-D9odA0GFOXQw63sMnhQPs34C+/xTuQJS+lV144K229E=";
      };
    }
    {
      def = {
        builder = ./build-3.3.2.nix;
        deps = {
          m4 = tvp.packages.m4;
          perl = tvp.packages.perl_5;
        };
        opts.upstreamPrerequisites = [
          "examples/c/reccalc/parse.c"
          "examples/c/lexcalc/parse.c"
        ];
        opts.postPatch = "touch -r doc/bison.1 configure";
        patches = [
          {
            file = ./reccalc-without-flex.patch;
            reason = "Initialize LEX_IS_FLEX when Flex is absent, preserving the shipped manual timestamp.";
          }
        ];
      };
      releases = {
        "3.4.2" = "sha256-/zkirzd9UU7KMCpmYtRw6Fe9GlkelqIFBQDfWp1Z+s8=";
      };
    }
    {
      def = {
        builder = ./build-3.3.2.nix;
        deps = {
          m4 = tvp.packages.m4;
          perl = tvp.packages.perl_5;
        };
      };
      releases = {
        "3.5.4" = "sha256-wN0VTfq6Y1U6iS1B3EAMe6qIzAah4uJ4E/3VA3FeTCg=";
      };
    }
    {
      def = {
        builder = ./build-3.3.2.nix;
        deps = {
          m4 = tvp.packages.m4;
          perl = tvp.packages.perl_5;
        };
        opts.upstreamPrerequisites = [
          "examples/c/reccalc/parse.c"
          "examples/c/lexcalc/parse.c"
        ];
        # Bundled gnulib nodiscard placement precedes the C23 fix.
        opts.cStandard = "gnu17";
        opts.upstreamPatches = [
          {
            file = ./patches/3.6.4-relative-compiler-inputs.patch;
            reason = "Pass generated @-prefixed test C/C++ filenames as explicit relative paths, preserving filename assertions without compiler response-file interpretation.";
          }
        ];
      };
      releases = {
        "3.6.4" = "sha256-gYPeZLU4PzY0lCx7FRvyV390JzsnMVdM3aio86CrE+k=";
        "3.7.6" = "sha256-adwLtG6o/DB9TKHgthyMNV6yB9Cwxp9PhGIyjnTXueo=";
      };
    }
    {
      def = {
        builder = ./build-3.3.2.nix;
        deps = {
          m4 = tvp.packages.m4;
          perl = tvp.packages.perl_5;
        };
      };
      releases = {
        "3.8" = "sha256-1dGE1CGu4VYDk5lzprDzcvkI7fskxbx0BpdJcCGtlFg=";
        "3.8.1" = "sha256-zjGKRxlhVft8JpErUTEC89DhR1fC5JXjRgh1e2EznFw=";
        "3.8.2" = "sha256-BsnhO99+sk1M62tZIFpPZ8LH5yExGWREMP6C+9FKCrs=";
      };
    }
  ];
  pname = "bison";
  retained = import ./retained { inherit pkgs tvp; };
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable;
    inherit (retained) packageMeta;
    source =
      { version, sha256 }:
      import <nix/fetchurl.nix> {
        url = "https://mirrors.kernel.org/gnu/bison/bison-${version}.tar.gz";
        inherit sha256;
      };
    tests = import ./tests;
    testDeps = {
      flex = tvp.packages.flex;
      autoconf = tvp.packages.autoconf;
      sentinel = (import ../../../bases/source-gnu/tests/probes.nix { }).sentinel;
      alternateSource = (import ../../../bootstrap/source-cmake-prerequisite-tests.nix { }).alternate;
    };
  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes.bison = family // {
    constructionRecipe = retained;
  };
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}

{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  defs = tvpLib.packages.mkDefs {
    "3.0.5" = {
      builder = ./build-3.0.5.nix;
      base = tvp.bases.default;
      deps = {
        m4 = tvp.packages.m4;
        perl = tvp.packages.perl_5;
      };
    };
    "3.4.2" = {
      builder = ./build-3.0.5.nix;
      base = tvp.bases.default;
      deps = {
        m4 = tvp.packages.m4;
        perl = tvp.packages.perl_5;
      };
      # Keep the shipped manual: its configure dependency tracks version changes,
      # and this patch only corrects optional example detection.
      opts.postPatch = "touch -r doc/bison.1 configure";
      patches = [
        {
          file = ./reccalc-without-flex.patch;
          reason = "Initialize LEX_IS_FLEX when no lexer is found, so the Flex-only reccalc example stays disabled instead of racing its no-op scanner generation during parallel build and install.";
        }
      ];
    };
    "3.6.4" = {
      builder = ./build-3.0.5.nix;
      base = tvp.bases.default;
      deps = {
        m4 = tvp.packages.m4;
        perl = tvp.packages.perl_5;
      };
      # Bundled gnulib places nodiscard after inline. GNU17 uses its GNU
      # attribute spelling; 3.8 corrects placement for the C23 spelling.
      opts.cStandard = "gnu17";
    };

  };
  versionTable = tvpLib.packages.mkTable [
    {
      def = defs."3.0.5";
      releases."3.0.5" = "sha256-zTmdK+4zr6cSusSx9ENOIDeem0CZvORxieCadnWi1WY=";
      releases."3.1" = "sha256-p8s2tVMW7uxiaGXAPSpEIQYXoXx9OT7mPYVT4GSe6UY=";
      releases."3.2.4" = "sha256-y2c+IpjTS15Gun3wZBr6c02hRXzkfeSRhjQHpYfux5o=";
      releases."3.3.2" = "sha256-D9odA0GFOXQw63sMnhQPs34C+/xTuQJS+lV144K229E=";
    }
    {
      def = defs."3.4.2";
      releases."3.4.2" = "sha256-/zkirzd9UU7KMCpmYtRw6Fe9GlkelqIFBQDfWp1Z+s8=";
    }
    {
      def = defs."3.0.5";
      releases."3.5.4" = "sha256-wN0VTfq6Y1U6iS1B3EAMe6qIzAah4uJ4E/3VA3FeTCg=";
      releases."3.8" = "sha256-1dGE1CGu4VYDk5lzprDzcvkI7fskxbx0BpdJcCGtlFg=";
      releases."3.8.1" = "sha256-zjGKRxlhVft8JpErUTEC89DhR1fC5JXjRgh1e2EznFw=";
      releases."3.8.2" = "sha256-BsnhO99+sk1M62tZIFpPZ8LH5yExGWREMP6C+9FKCrs=";
    }
    {
      def = defs."3.6.4";
      releases."3.6.4" = "sha256-gYPeZLU4PzY0lCx7FRvyV390JzsnMVdM3aio86CrE+k=";
      releases."3.7.6" = "sha256-adwLtG6o/DB9TKHgthyMNV6yB9Cwxp9PhGIyjnTXueo=";
    }
  ];
  pname = "bison";
  packageArgs = {
    infra = {
      inherit (pkgs) lib fetchurl;
    };
    inherit pname versionTable;
    extraArgs.mkTests = pkgs.lib.makeOverridable (
      { pkgs }:
      package:
      import ./tests {
        inherit tvpLib package;
        pkgs = tvpLib.tests.withBase {
          inherit pkgs;
          base.stdenv = package.stdenv;
        };
      }
    ) { inherit pkgs; };
    packageMeta.upstream = {
      type = "directory-index";
      url = "https://mirrors.kernel.org/gnu/bison/";
      pattern = "bison-[0-9][^\"]*\\.tar\\.gz";
      normalise =
        file:
        if pkgs.lib.hasPrefix "bison-" file && pkgs.lib.hasSuffix ".tar.gz" file then
          pkgs.lib.removeSuffix ".tar.gz" (pkgs.lib.removePrefix "bison-" file)
        else
          null;
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

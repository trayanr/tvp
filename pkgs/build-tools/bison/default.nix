{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  defs = tvpLib.packages.mkDefs {
    "3.0.5" = {
      builder = ./build-3.0.5.nix;
      base = tvp.bases.default;
      deps = {
        m4 = tvp.packages.m4_1_4_21;
        perl = tvp.packages.perl_5_44_0;
      };
    };
  };
  versionTable = tvpLib.packages.mkTable [
    {
      def = defs."3.0.5";
      releases."3.0.5" = "sha256-zTmdK+4zr6cSusSx9ENOIDeem0CZvORxieCadnWi1WY=";
      releases."3.1" = "sha256-p8s2tVMW7uxiaGXAPSpEIQYXoXx9OT7mPYVT4GSe6UY=";
      releases."3.2.4" = "sha256-y2c+IpjTS15Gun3wZBr6c02hRXzkfeSRhjQHpYfux5o=";
      releases."3.3.2" = "sha256-D9odA0GFOXQw63sMnhQPs34C+/xTuQJS+lV144K229E=";
      releases."3.4.2" = "sha256-/zkirzd9UU7KMCpmYtRw6Fe9GlkelqIFBQDfWp1Z+s8=";
      releases."3.5.4" = "sha256-wN0VTfq6Y1U6iS1B3EAMe6qIzAah4uJ4E/3VA3FeTCg=";
      releases."3.6.4" = "sha256-gYPeZLU4PzY0lCx7FRvyV390JzsnMVdM3aio86CrE+k=";
      releases."3.7.6" = "sha256-adwLtG6o/DB9TKHgthyMNV6yB9Cwxp9PhGIyjnTXueo=";
      releases."3.8.2" = "sha256-BsnhO99+sk1M62tZIFpPZ8LH5yExGWREMP6C+9FKCrs=";
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
  variants = tvpLib.packages.mkVariants (
    packageArgs
    // {
      inherit pkgs;
      profiles = {
        gcc13 = {
          base = tvp.bases.gcc13;
          versions."3.8.2" = {
            deps = {
              m4 = tvp.variants.gcc13.m4_1_4_21;
              perl = tvp.variants.gcc13.perl_5_44_0;
            };
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

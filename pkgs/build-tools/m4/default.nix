{ pkgs, tvp }:
let
  tvpLib = tvp.lib;

  defs = tvpLib.packages.mkDefs {
    "1.4.17" = {
      builder = ./build-1.4.17.nix;
      base = tvp.bases.default;
      deps = { };
    };
    "1.4.19" = {
      builder = ./build-1.4.17.nix;
      base = tvp.bases.default;
      deps = { };
      # Bundled gnulib puts the C23 nodiscard attribute after inline. GNU17
      # retains its supported GNU attribute form; 1.4.20 fixes the placement.
      opts.cStandard = "gnu17";
    };
    "1.4.21" = {
      builder = ./build-1.4.17.nix;
      base = tvp.bases.default;
      deps = { };
    };
  };

  versionTable = tvpLib.packages.mkTable (import ./1.nix { inherit defs; });

  pname = "m4";

  packageArgs = {
    infra = {
      inherit (pkgs) lib fetchurl;
    };
    inherit pname;
    inherit versionTable;

    extraArgs = {
      mkTests = pkgs.lib.makeOverridable (
        { pkgs }:
        m4:
        import ./tests {
          inherit tvpLib m4;
          pkgs = tvpLib.tests.withBase {
            inherit pkgs;
            base.stdenv = m4.stdenv;
          };
        }
      ) { inherit pkgs; };
    };

    packageMeta = {
      upstream = {
        type = "directory-index";
        url = "https://mirrors.kernel.org/gnu/m4/";
        pattern = "m4-[0-9][^\"]*\\.tar\\.gz";

        normalise =
          file:
          if pkgs.lib.hasPrefix "m4-" file && pkgs.lib.hasSuffix ".tar.gz" file then
            pkgs.lib.removeSuffix ".tar.gz" (pkgs.lib.removePrefix "m4-" file)
          else
            null;

        include = version: builtins.match "[0-9].*" version != null;
      };
    };
  };

  canonical = tvpLib.packages.mkVersions packageArgs;

in
{
  recipes.${pname} = packageArgs;
  inherit canonical;
  aliases = tvpLib.packages.mkAliases {
    inherit
      pname
      versionTable
      canonical
      ;
  };
}

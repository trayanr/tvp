{ pkgs, tvp }:
let
  tvpLib = tvp.lib;

  defs = tvpLib.packages.mkDefs {
    "2.10" = {
      builder = ./build-2.10.nix;
      base = tvp.bases.default;
      deps = {
        m4 = tvp.packages.m4_1_4_21;
        perl = tvp.packages.perl_5_44_0;
      };
      opts.modernInit = false;
      opts.license = pkgs.lib.licenses.gpl2Plus;
    };
    "2.50" = {
      builder = ./build-2.10.nix;
      base = tvp.bases.default;
      deps = {
        m4 = tvp.packages.m4_1_4_21;
        perl = tvp.packages.perl_5_44_0;
      };
      opts.license = pkgs.lib.licenses.gpl2Plus;
    };
    "2.53" = {
      builder = ./build-2.10.nix;
      base = tvp.bases.default;
      deps = {
        m4 = tvp.packages.m4_1_4_21;
        perl = tvp.packages.perl_5_24_4;
      };
      opts.license = pkgs.lib.licenses.gpl2Plus;
    };
    "2.65" = {
      builder = ./build-2.10.nix;
      base = tvp.bases.default;
      deps = {
        m4 = tvp.packages.m4_1_4_21;
        perl = tvp.packages.perl_5_44_0;
      };
    };
    "2.73" = {
      builder = ./build-2.10.nix;
      base = tvp.bases.default;
      deps = {
        m4 = tvp.packages.m4_1_4_21;
        perl = tvp.packages.perl_5_44_0;
      };
    };
  };

  versionTable = tvpLib.packages.mkTable (import ./2.nix { inherit defs; });

  pname = "autoconf";

  packageArgs = {
    infra = {
      inherit (pkgs) lib fetchurl;
    };
    inherit pname;
    inherit versionTable;

    extraArgs = {
      mkTests = pkgs.lib.makeOverridable (
        { pkgs }:
        autoconf:
        import ./tests {
          inherit tvpLib autoconf;
          pkgs = tvpLib.tests.withBase {
            inherit pkgs;
            base.stdenv = autoconf.stdenv;
          };
        }
      ) { inherit pkgs; };
    };

    # Not git-tags: the tag set carries betas, uses two naming conventions, and
    # includes AUTOCONF-2.51 — a version upstream never released, and says so in
    # NEWS. The release directory carries only releases.
    packageMeta = {
      upstream = {
        type = "directory-index";
        url = "https://mirrors.kernel.org/gnu/autoconf/";
        pattern = "autoconf-[0-9][^\"]*\\.tar\\.gz";

        normalise =
          file:
          if pkgs.lib.hasPrefix "autoconf-" file && pkgs.lib.hasSuffix ".tar.gz" file then
            pkgs.lib.removeSuffix ".tar.gz" (pkgs.lib.removePrefix "autoconf-" file)
          else
            null;

        # autoconf-latest.tar.gz is a moving alias and is excluded by requiring
        # a leading digit. Betas live on alpha.gnu.org, not here.
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

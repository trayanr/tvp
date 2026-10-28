{ pkgs, tvp }:
let
  tvpLib = tvp.lib;

  defs = tvpLib.packages.mkDefs {
    "2.69" = {
      builder = ./build-2.69.nix;
      base = tvp.bases.default;
      deps = {
        m4 = tvp.packages.m4_1_4_21;
        perl = tvp.packages.perl_5_44_0;
      };
    };
    "2.73" = {
      builder = ./build-2.69.nix;
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
  variants = tvpLib.packages.mkVariants (
    packageArgs
    // {
      inherit pkgs;
      profiles = {
        gcc13 = {
          base = tvp.bases.gcc13;
          versions."2.73" = {
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
  aliases = tvpLib.packages.mkAliases {
    inherit
      pname
      versionTable
      canonical
      ;
  };
}

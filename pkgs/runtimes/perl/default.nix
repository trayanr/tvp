{ pkgs, tvp }:
let
  tvpLib = tvp.lib;

  defs = tvpLib.packages.mkDefs {
    "5.24.4" = {
      builder = ./build-5.24.4.nix;
      base = tvp.bases.gcc9;
      deps.coreutils = tvp.packages.coreutils;
    };
    "5.28.3" = {
      builder = ./build-5.24.4.nix;
      # gcc 9 reports 9.5.0, so Configure's `1*` glob does not match and the
      # struct-return patch this builder would otherwise apply is unnecessary.
      base = tvp.bases.gcc9;
      deps = {
        coreutils = pkgs.coreutils;
      };
    };

    "5.30.3" = {
      builder = ./build-5.30.nix;
      # Configure's malloc()/free() probes predate C23; GNU17 detects their
      # actual void pointer/void types. 5.36 removes these old probes.
      opts.cStandard = "gnu17";
      base = tvp.bases.default;
      deps = {
        coreutils = pkgs.coreutils;
      };
    };

    "5.36.3" = {
      builder = ./build-5.36.nix;
      base = tvp.bases.default;
      deps = { };
    };
  };

  versionTable = tvpLib.packages.mkTable (import ./5.nix { inherit defs; });

  pname = "perl";

  packageArgs = {
    infra = {
      inherit (pkgs) lib fetchurl;
    };
    inherit pname;
    inherit versionTable;

    extraArgs = {
      mkTests = pkgs.lib.makeOverridable (
        { pkgs }:
        perl:
        import ./tests {
          inherit tvpLib perl;
          pkgs = tvpLib.tests.withBase {
            inherit pkgs;
            base.stdenv = perl.stdenv;
          };
        }
      ) { inherit pkgs; };
    };

    packageMeta = {
      upstream = {
        type = "directory-index";
        url = "https://www.cpan.org/src/5.0/";
        pattern = "perl-5\\.[0-9][^\"]*\\.tar\\.gz";

        normalise =
          file:
          if pkgs.lib.hasPrefix "perl-" file && pkgs.lib.hasSuffix ".tar.gz" file then
            pkgs.lib.removeSuffix ".tar.gz" (pkgs.lib.removePrefix "perl-" file)
          else
            null;

        # Perl marks development releases by parity, not by a suffix: an odd
        # second component (5.45, 5.9, 5.11) is a devel series and was never a
        # stable release. RC and TRIAL tarballs are also published here.
        include =
          version:
          let
            minor = pkgs.lib.toInt (pkgs.lib.elemAt (pkgs.lib.splitVersion version) 1);
          in
          builtins.match "[0-9].*" version != null
          && pkgs.lib.mod minor 2 == 0
          && !(pkgs.lib.hasInfix "RC" version || pkgs.lib.hasInfix "TRIAL" version);
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

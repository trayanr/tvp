{ pkgs, tvp }:
let
  tvpLib = tvp.lib;

  # Every version names one of these. A version that differs forks a definition
  # rather than overriding it, so the entries below hold only a hash and a status.
  defs = tvpLib.packages.mkDefs {
    "0.9.6" = {
      builder = ./build-0.9.nix;
      base = tvp.bases.default;
      deps = {
        perl = tvp.packages.perl_5_44_0;
      };
    };

    "0.9.8" = {
      builder = ./build-0.9.nix;
      base = tvp.bases.default;
      deps = {
        perl = tvp.packages.perl_5_44_0;
      };
      opts = {
        hardeningDisable = [ "format" ];
      };
    };

    "1.0.0" = {
      builder = ./build-1.0.nix;
      base = tvp.bases.default;
      deps = {
        perl = tvp.packages.perl_5_44_0;
      };
    };

    # 1.1.0's Configure does `use File::Glob 'glob'`, which perl stopped exporting at 5.30.
    "1.1.0" = {
      builder = ./build-1.1.0.nix;
      base = tvp.bases.default;
      deps = {
        perl = tvp.packages.perl_5_28_3;
      };
      opts = {
        pbkdf2 = false;
      };
    };

    "1.1.1" = {
      builder = ./build-1.1.0.nix;
      base = tvp.bases.default;
      deps = {
        perl = tvp.packages.perl_5_44_0;
      };
    };

    "3.0.0" = {
      builder = ./build-3.0.nix;
      base = tvp.bases.default;
      deps = {
        perl = tvp.packages.perl_5_44_0;
      };
    };
  };

  inherit (tvpLib.packages) merge mkTable;

  versionTable = merge {
    "0" = mkTable (import ./0.nix { inherit defs; });
    "1" = mkTable (import ./1.nix { inherit defs; });
    "3" = mkTable (import ./3.nix { inherit defs; });
    "4" = mkTable (import ./4.nix { inherit defs; });
  };

  pname = "openssl";

  canonical = tvpLib.packages.mkVersions {
    infra = {
      inherit (pkgs) lib fetchurl;
    };
    inherit pname;
    inherit versionTable;

    extraArgs = {
      mkTests =
        openssl:
        import ./tests {
          inherit pkgs tvpLib openssl;
        };
    };

    packageMeta = {
      upstream = {
        type = "git-tags";
        url = "https://github.com/openssl/openssl";

        # Releases that exist upstream and cannot be packaged at all. Listed so
        # the delta separates work from dead ends, rather than showing both as
        # "not packaged" forever.
        unavailable = [
          {
            versions = [
              "0.9.1c"
              "0.9.2b"
              "0.9.3"
              "0.9.3a"
              "0.9.4"
              "0.9.5"
              "0.9.5a"
              "0.9.6a"
              "0.9.6b"
              "0.9.6c"
              "0.9.6d"
              "0.9.6e"
              "0.9.6f"
              "0.9.6g"
              "0.9.6h"
            ];
            reason = "No tarball is served by openssl.org or by GitHub releases. Only git-archive snapshots survive, and a snapshot is a different artifact from the release.";
          }
        ];

        # Two tag conventions, split at 3.0: OpenSSL_1_1_1w and openssl-3.0.0.
        # Anything else (rsaref, the fips branches) is not a release.
        normalise =
          tag:
          if pkgs.lib.hasPrefix "OpenSSL_" tag then
            pkgs.lib.replaceStrings [ "_" ] [ "." ] (pkgs.lib.removePrefix "OpenSSL_" tag)
          else if pkgs.lib.hasPrefix "openssl-" tag then
            pkgs.lib.removePrefix "openssl-" tag
          else
            null;

        # A release version starts with a digit. That rule, rather than another
        # blacklist entry, is what drops OpenSSL_FIPS_1_0 — the separately
        # distributed FIPS Object Module, which has no openssl-*.tar.gz at all.
        # "-post-reformat" and friends tag repository maintenance, not releases.
        include =
          version:
          let
            # Published, then pulled: no tarball is served for either, and 3.0.6's
            # tag no longer exists. A rule cannot express this, so the predicate
            # closes over the list rather than a separate `exclude` field.
            withdrawn = [
              "1.1.1r" # withdrawn 2022-10-11, superseded same day by 1.1.1s
              "3.0.6" # withdrawn 2022-10-11, superseded same day by 3.0.7
            ];
          in
          builtins.match "[0-9].*" version != null
          && !(pkgs.lib.elem version withdrawn)
          && !(
            pkgs.lib.hasInfix "pre" version
            || pkgs.lib.hasInfix "alpha" version
            || pkgs.lib.hasInfix "beta" version
            || pkgs.lib.hasInfix "rc" version
            || pkgs.lib.hasInfix "-post-" version
          );
      };
    };
  };

in
{
  inherit canonical;
  aliases = tvpLib.packages.mkAliases {
    inherit
      pname
      versionTable
      canonical
      ;
  };
}

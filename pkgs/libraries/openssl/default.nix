{ pkgs, tvp }:
let
  tvpLib = tvp.lib;

  versionTable = tvpLib.packages.merge {
    "0" = import ./0.nix { inherit pkgs tvp; };
    "1" = import ./1 { inherit pkgs tvp; };
    "3" = import ./3 { inherit pkgs tvp; };
    "4" = import ./4.nix { inherit pkgs tvp; };
  };

  canonical = tvpLib.packages.mkVersions {
    # perl is still nixpkgs', and every Configure in the catalogue runs under it. The
    # 1.1.0 line names its own; the rest inherit whatever nixpkgs ships, which is an
    # M9 worklist entry rather than a settled pin.
    infra = {
      inherit (pkgs) lib fetchurl perl;
    };
    pname = "openssl";
    inherit versionTable;
    defaultBase = tvp.bases.default;

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

  # No `openssl_1_1_1`: upstream shipped a release literally called 1.1.1, so
  # that name is canonical and an alias may not shadow it.
  aliases = {
    openssl_1_0 = canonical.openssl_1_0_2u;
    openssl_1_1 = canonical.openssl_1_1_1w;
    openssl_1 = canonical.openssl_1_1_1w;

    openssl_0_9 = canonical.openssl_0_9_8zh;
    openssl_0 = canonical.openssl_0_9_8zh;

    openssl_3_0 = canonical.openssl_3_0_21;
    openssl_3_1 = canonical.openssl_3_1_8;
    openssl_3_2 = canonical.openssl_3_2_6;
    openssl_3_3 = canonical.openssl_3_3_7;
    openssl_3_4 = canonical.openssl_3_4_6;
    openssl_3_5 = canonical.openssl_3_5_7;
    openssl_3_6 = canonical.openssl_3_6_3;
    openssl_3 = canonical.openssl_3_6_3;

    openssl_4_0 = canonical.openssl_4_0_1;
    openssl_4 = canonical.openssl_4_0_1;

    openssl = canonical.openssl_4_0_1;
  };
in
canonical // tvpLib.packages.checkAliases { inherit canonical aliases; }

{ pkgs, tvp }:
let
  tvpLib = tvp.lib;

  versionTable = {
    "1.1.1u" = {
      builder = ./build-1.1.1.nix;
      sha256 = "sha256-4vjYS1I+7NBse+diaDA3AwD7zBU4a/UULXJ1j2lj68Y=";
      deps = { };
    };

    "1.1.1w" = {
      builder = ./build-1.1.1.nix;
      sha256 = "sha256-zzCYlQy02FOtlcCEHx+cbT3BAtzPys1SHZOSUgi3asg=";
      deps = { };
    };
  };

  canonical = tvpLib.packages.mkVersions {
    inherit (pkgs) callPackage;
    pname = "openssl";
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

        # "-post-reformat" and friends tag repository maintenance, not releases.
        include =
          version:
          !(
            pkgs.lib.hasInfix "pre" version
            || pkgs.lib.hasInfix "alpha" version
            || pkgs.lib.hasInfix "beta" version
            || pkgs.lib.hasInfix "rc" version
            || pkgs.lib.hasInfix "-post-" version
            || pkgs.lib.hasInfix "fips" version
          );
      };
    };
  };

  aliases = {
    openssl_1_1_1 = canonical.openssl_1_1_1w;
    openssl_1_1 = canonical.openssl_1_1_1w;
  };
in
canonical // tvpLib.packages.checkAliases { inherit canonical aliases; }

{ pkgs, tvp }:
let
  tvpLib = tvp.lib;

  versionTable = {
    "1.17.3" = {
      builder = ./build-1.17.3.nix;
      sha256 = "sha256-vEv3W1SLJ0UaqfRDsYxGpzndIq1596X5C0hTdqZ9w1I=";
      deps = {
        ruby = tvp.packages.ruby_2_7_0;
      };
    };

    "2.1.2" = {
      builder = ./build-1.17.3.nix;
      sha256 = "sha256-o9icmn+/6TZFEsrBC8jcT5w3DkE3XAPNNsrTHu9vuWE=";
      deps = {
        ruby = tvp.packages.ruby_2_7_0;
      };
    };

    # 2.5 requires Ruby >= 3.0.
    "2.5.11" = {
      builder = ./build-1.17.3.nix;
      sha256 = "sha256-3XhL/lODSzmlbmQtvG4eyhmi5kVOTVOZTLcpgAWsTC4=";
      deps = {
        ruby = tvp.packages.ruby_3_3_4;
      };
    };

    "2.5.20" = {
      builder = ./build-1.17.3.nix;
      sha256 = "sha256-g7zLXMxFbjRwiaoFMY7NJ7uYQMqmTtFsFwO1DUmwq5Q=";
      deps = {
        ruby = tvp.packages.ruby_3_3_4;
      };
    };
  };

  canonical = tvpLib.packages.mkVersions {
    inherit (pkgs) callPackage;
    pname = "bundler";
    inherit versionTable;
    # bundler is built by nixpkgs' buildRubyGem rather than by
    # stdenv.mkDerivation, so it takes no stdenv and there is nothing for a base
    # to substitute. Declared rather than inferred: this is an M9 worklist entry,
    # and it is the only package in TVP that is not on a base.
    defaultBase = null;

    extraArgs = {
      mkTests =
        bundler:
        import ./tests {
          inherit pkgs tvpLib bundler;
        };
    };

    packageMeta = {
      upstream = {
        type = "rubygems";
        url = "https://rubygems.org/api/v1/versions/bundler.json";

        include =
          version:
          !(
            pkgs.lib.hasInfix "pre" version
            || pkgs.lib.hasInfix "rc" version
            || pkgs.lib.hasInfix "beta" version
          );
      };
    };
  };

  aliases = {
    bundler = canonical.bundler_2_5_20;
  };
in
canonical // tvpLib.packages.checkAliases { inherit canonical aliases; }

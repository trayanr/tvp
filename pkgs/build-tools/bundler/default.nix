{ pkgs, tvp }:
let
  tvpLib = tvp.lib;

  defs = tvpLib.packages.mkDefs {
    "1.17.3" = {
      builder = ./build-1.17.3.nix;
      base = tvp.bases.gcc13;
      deps = {
        ruby = tvp.packages.ruby_2_7_0;
      };
    };

    # 2.5 requires Ruby >= 3.0.
    "2.5.11" = {
      builder = ./build-1.17.3.nix;
      base = tvp.bases.gcc13;
      deps = {
        ruby = tvp.packages.ruby_3_3_4;
      };
    };
  };

  versionTable = tvpLib.packages.mkTable [
    {
      def = defs."1.17.3";
      releases = {
        "1.17.3" = "sha256-vEv3W1SLJ0UaqfRDsYxGpzndIq1596X5C0hTdqZ9w1I=";
        "2.1.2" = "sha256-o9icmn+/6TZFEsrBC8jcT5w3DkE3XAPNNsrTHu9vuWE=";
      };
    }

    {
      def = defs."2.5.11";
      releases = {
        "2.5.11" = "sha256-3XhL/lODSzmlbmQtvG4eyhmi5kVOTVOZTLcpgAWsTC4=";
        "2.5.20" = "sha256-g7zLXMxFbjRwiaoFMY7NJ7uYQMqmTtFsFwO1DUmwq5Q=";
      };
    }
  ];

  canonical = tvpLib.packages.mkVersions {
    infra = {
      inherit (pkgs) lib fetchurl;
    };
    pname = "bundler";
    inherit versionTable;

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

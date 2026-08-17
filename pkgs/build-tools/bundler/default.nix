{ pkgs, tvp }:
let
  tvpLib = tvp.lib;

  line_1 = {
    builder = ./build-1.17.3.nix;
    deps = {
      ruby = tvp.packages.ruby_2_7_0;
    };
  };

  # 2.5 requires Ruby >= 3.0, which TVP does not have yet.
  line_2_5 = {
    builder = ./build-1.17.3.nix;
    deps = {
      ruby = pkgs.ruby;
    };
  };

  versionTable = {
    "1.17.3" = line_1 // {
      sha256 = "sha256-vEv3W1SLJ0UaqfRDsYxGpzndIq1596X5C0hTdqZ9w1I=";
    };
    "2.1.2" = line_1 // {
      sha256 = "sha256-o9icmn+/6TZFEsrBC8jcT5w3DkE3XAPNNsrTHu9vuWE=";
    };
    "2.5.11" = line_2_5 // {
      sha256 = "sha256-3XhL/lODSzmlbmQtvG4eyhmi5kVOTVOZTLcpgAWsTC4=";
    };
    "2.5.20" = line_2_5 // {
      sha256 = "sha256-g7zLXMxFbjRwiaoFMY7NJ7uYQMqmTtFsFwO1DUmwq5Q=";
    };
  };

  canonical = tvpLib.packages.mkVersions {
    inherit (pkgs) callPackage;
    pname = "bundler";
    inherit versionTable;
  };

  aliases = {
    bundler = canonical.bundler_2_5_20;
  };
in
canonical // tvpLib.packages.checkAliases { inherit canonical aliases; }

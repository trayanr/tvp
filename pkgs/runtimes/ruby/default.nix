{ pkgs, tvp }:
let
  tvpLib = tvp.lib;

  # Dependencies are declared per line, not per patch release.
  line_2_7 = {
    builder = ./build-2.7.nix;
    deps = {
      openssl = tvp.packages.openssl_1_1_1w;
      inherit (pkgs) readline zlib gdbm;
    };
  };

  versionTable = {
    "2.7.0" = line_2_7 // {
      sha256 = "sha256-jJmqk7Xi8byEN9G7vv0nsT52lAJTMfdyRdDAaO8fjL4=";
    };
    "2.7.8" = line_2_7 // {
      sha256 = "sha256-wtq2PLyPKgVSYQitQZ76Y6Z+1AdNu8+fwrHKZky0W6A=";
    };
  };

  canonical = tvpLib.packages.mkVersions {
    inherit (pkgs) callPackage;
    pname = "ruby";
    inherit versionTable;

    extraArgs = {
      mkTests =
        ruby:
        import ./tests {
          inherit pkgs tvpLib ruby;
        };
    };
  };

  aliases = {
    ruby_2_7 = canonical.ruby_2_7_8;
    ruby_2 = canonical.ruby_2_7_8;
    ruby = canonical.ruby_2_7_8;
  };
in
canonical // tvpLib.packages.checkAliases { inherit canonical aliases; }

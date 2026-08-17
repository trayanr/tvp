{ pkgs, tvp }:
let
  tvpLib = tvp.lib;

  line_1_1_1 = {
    builder = ./build-1.1.1.nix;
    deps = { };
  };

  versionTable = {
    "1.1.1u" = line_1_1_1 // {
      sha256 = "sha256-4vjYS1I+7NBse+diaDA3AwD7zBU4a/UULXJ1j2lj68Y=";
    };
    "1.1.1w" = line_1_1_1 // {
      sha256 = "sha256-zzCYlQy02FOtlcCEHx+cbT3BAtzPys1SHZOSUgi3asg=";
    };
  };

  canonical = tvpLib.packages.mkVersions {
    inherit (pkgs) callPackage;
    pname = "openssl";
    inherit versionTable;
  };

  aliases = {
    openssl_1_1_1 = canonical.openssl_1_1_1w;
    openssl_1_1 = canonical.openssl_1_1_1w;
  };
in
canonical // tvpLib.packages.checkAliases { inherit canonical aliases; }

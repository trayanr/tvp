{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  defs = tvpLib.packages.mkDefs {
    "1.13.0" = {
      builder = ./build-1.13.0.nix;
      base = tvp.bases.default;
      deps = {
        python = tvp.packages.python-minimal_3_12_5;
        bash = tvp.packages.bash_5_2_37;
      };
      patches = [
        {
          file = ./patches/store-shell.patch;
          reason = "Store-layout adaptation: use the declared Bash instead of /bin/sh, which is absent in Nix build sandboxes.";
        }
      ];
    };
  };
  versionTable = tvpLib.packages.mkTable [
    {
      def = defs."1.13.0";
      releases = {
        "1.13.0" = "sha256-8IZB0ACZqeQNROwBRvhBxHKuWLfm3VF77jlFz9kjzt8=";
        "1.13.1" = "sha256-8AVa0Dab8uNylVulUSjQAM/MIXdwV4BgFbReSsy+vyM=";
        "1.13.2" = "sha256-l01rL07u+iViXTTaPLNr3Ovn+85A9MFqwINf0cDLrhc=";
      };
    }
  ];
  pname = "ninja";
  canonical = tvpLib.packages.mkVersions {
    infra = {
      inherit (pkgs) lib fetchurl;
    };
    inherit pname versionTable;
    extraArgs.mkTests = pkgs.lib.makeOverridable (
      { pkgs }:
      package:
      import ./tests {
        inherit tvpLib package;

        pkgs = tvpLib.tests.withBase {
          inherit pkgs;
          base.stdenv = package.stdenv;
        };
      }
    ) { inherit pkgs; };
    packageMeta.upstream = {
      type = "git-tags";
      url = "https://github.com/ninja-build/ninja.git";
      normalise = tag: pkgs.lib.removePrefix "v" tag;
      include = version: builtins.match "[0-9]+(\\.[0-9]+)*" version != null;
    };
  };
in
{
  inherit canonical;
  aliases = tvpLib.packages.mkAliases { inherit pname versionTable canonical; };
}

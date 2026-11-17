{ pkgs, tvp }:
let
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build.nix;
        deps = {
          runtimeShell = tvp.packages.bash_5;
          browsePython = tvp.packages.python_3;
        };
        patches = [
          {
            file = ./patches/store-shell.patch;
            reason = "Store-layout adaptation: bind subprocess commands to the declared build shell before final runtime-shell slot relocation.";
          }
        ];
      };
      releases = {
        "1.13.0" = "sha256-8IZB0ACZqeQNROwBRvhBxHKuWLfm3VF77jlFz9kjzt8=";
        "1.13.1" = "sha256-8AVa0Dab8uNylVulUSjQAM/MIXdwV4BgFbReSsy+vyM=";
        "1.13.2" = "sha256-l01rL07u+iViXTTaPLNr3Ovn+85A9MFqwINf0cDLrhc=";
      };
    }
  ];

  pname = "ninja";
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable;
    source = tvp.lib.sources.archive {
      url = version: "https://github.com/ninja-build/ninja/archive/refs/tags/v${version}.tar.gz";
      fetch =
        { version, sha256 }:
        import <nix/fetchurl.nix> {
          name = "ninja-${version}.tar.gz";
          url = "https://github.com/ninja-build/ninja/archive/refs/tags/v${version}.tar.gz";
          inherit sha256;
        };
      discovery = {
        type = "git-tags";
        url = "https://github.com/ninja-build/ninja.git";
        normalise = tag: pkgs.lib.removePrefix "v" tag;
        include = version: builtins.match "[0-9]+(\\.[0-9]+)*" version != null;
      };
    };
    tests = import ./tests;
    testDeps = {
      alternateShell = tvp.bases.gcc_16.seed.shell;
      runtimeShell = tvp.packages.bash_5;
      alternateCoreutils = tvp.packages.coreutils;
      pkgConfig = tvp.packages.pkg-config;
      mpfr = tvp.packages.mpfr;
      sentinel = tvp.lib.tests.fixtures.sentinel;
      alternateSource = tvp.lib.tests.fixtures.alternateSource;
    };
  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes.ninja = family;
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}

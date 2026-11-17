{ pkgs, tvp }:
let
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build.nix;
        deps = {
          m4 = tvp.packages.m4;
          file = tvp.packages.file_5;
        };
        opts.rebuildSkeleton = true;
        # K&R fixtures are test-only; do not change the production C dialect.
        opts.checkCFlags = [ "-std=gnu17" ];
        patches = [
          {
            file = ./patches/2.6.2-null-restart.patch;
            reason = "Avoid forming a null C++ istream reference in yyrestart(NULL), preserving original null-stream semantics and restart assertions.";
          }
        ];
      };
      releases = {
        "2.6.1" = "sha256-PEP55ljkXoquPPafoRgD1gVQhl8COFKDDVV8XwYjwTs=";
      };
    }
    {
      def = {
        builder = ./build.nix;
        deps = {
          m4 = tvp.packages.m4;
          file = tvp.packages.file_5;
        };
        opts.rebuildSkeleton = true;
        patches = [
          {
            file = ./patches/2.6.2-null-restart.patch;
            reason = "Avoid forming a null C++ istream reference in yyrestart(NULL), preserving original null-stream semantics and restart assertions.";
          }
          {
            file = ./patches/2.6.2-manpage-prerequisites.patch;
            reason = "Backport shipped manual prerequisites from 2.6.3.";
          }
        ];
      };
      releases = {
        "2.6.2" = "sha256-mgFDehFVx5m33CUIYgVk74BrpmJQw2v1+QNLHCB8ssk=";
      };
    }
    {
      def = {
        builder = ./build.nix;
        deps = {
          m4 = tvp.packages.m4;
          file = tvp.packages.file_5;
        };
        opts.rebuildSkeleton = true;
        patches = [
          {
            file = ./patches/2.6.2-null-restart.patch;
            reason = "Avoid forming a null C++ istream reference in yyrestart(NULL), preserving original null-stream semantics and restart assertions.";
          }
        ];
      };
      releases = {
        "2.6.3" = "sha256-aLJ0IjPnR8Ri94FGKioeKZ3GIHQB2sjwu7MW9IVlwqo=";
      };
    }
    {
      def = {
        builder = ./build.nix;
        deps = {
          m4 = tvp.packages.m4;
          file = tvp.packages.file_5;
        };
      };
      releases = {
        "2.6.4" = "sha256-6HquAyvwfCb4WsDtMlCZjDdiHZX4vXSLMfFbM8Re6ZU=";
      };
    }
  ];
  pname = "flex";
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable;

    source = tvp.lib.sources.archive {
      url =
        version: "https://github.com/westes/flex/releases/download/v${version}/flex-${version}.tar.gz";
      discovery = {
        type = "git-tags";
        url = "https://github.com/westes/flex.git";
        normalise =
          tag:
          if pkgs.lib.hasPrefix "v" tag then
            pkgs.lib.removePrefix "v" tag
          else if pkgs.lib.hasPrefix "flex-" tag then
            pkgs.lib.removePrefix "flex-" tag
          else
            null;
        include = version: builtins.match "[0-9]+(\\.[0-9]+)*" version != null;
      };
    };
    tests = import ./tests;
    testDeps = {
      bison = tvp.packages.bison;
      sentinel = tvp.lib.tests.fixtures.sentinel;
      alternateSource = tvp.lib.tests.fixtures.alternateSource;
    };
  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes.flex = family;
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}

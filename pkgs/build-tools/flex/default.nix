{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  base = tvp.bases.default;
  defs = tvpLib.packages.mkDefs {
    "2.6.1" = {
      builder = ./build-2.6.1.nix;
      inherit base;
      deps = {
        bison = tvp.packages.bison;
        m4 = tvp.packages.m4;
      };
    };
    "2.6.2" = {
      builder = ./build-2.6.1.nix;
      inherit base;
      deps = {
        bison = tvp.packages.bison;
        m4 = tvp.packages.m4;
      };
      patches = [
        {
          file = ./patches/2.6.2-manpage-prerequisites.patch;
          reason = "Backport the 2.6.3 man-page dependency rule: rebuilding the executable alone must not regenerate and delete the shipped manual when help2man is absent.";
        }
      ];
    };
  };
  versionTable = tvpLib.packages.mkTable [
    {
      def = defs."2.6.1";
      releases."2.6.1" = "sha256-PEP55ljkXoquPPafoRgD1gVQhl8COFKDDVV8XwYjwTs=";
    }
    {
      def = defs."2.6.2";
      releases."2.6.2" = "sha256-mgFDehFVx5m33CUIYgVk74BrpmJQw2v1+QNLHCB8ssk=";
    }
    {
      def = defs."2.6.1";
      releases."2.6.3" = "sha256-aLJ0IjPnR8Ri94FGKioeKZ3GIHQB2sjwu7MW9IVlwqo=";
      releases."2.6.4" = "sha256-6HquAyvwfCb4WsDtMlCZjDdiHZX4vXSLMfFbM8Re6ZU=";
    }
  ];
  pname = "flex";
  canonical = tvpLib.packages.mkVersions {
    infra = {
      inherit (pkgs) lib fetchurl;
    };
    inherit pname versionTable;
    extraArgs.mkTests = pkgs.lib.makeOverridable (
      { pkgs }: package: import ./tests { inherit pkgs tvpLib package; }
    ) { pkgs = tvpLib.tests.withBase { inherit pkgs base; }; };
    packageMeta.upstream = {
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
in
{
  inherit canonical;
  aliases = tvpLib.packages.mkAliases { inherit pname versionTable canonical; };
}

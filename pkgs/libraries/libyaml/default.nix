{ pkgs, tvp }:
let
  tvpLib = tvp.lib;

  defs = tvpLib.packages.mkDefs {
    "0.0.1" = {
      builder = ./build-0.0.1.nix;
      base = tvp.bases.default;
      deps = { };
    };
  };

  versionTable = tvpLib.packages.mkTable (import ./0.nix { inherit defs; });

  pname = "libyaml";

  canonical = tvpLib.packages.mkVersions {
    infra = {
      inherit (pkgs) lib fetchurl;
    };
    inherit pname;
    inherit versionTable;

    extraArgs = {
      mkTests =
        libyaml:
        import ./tests {
          inherit pkgs tvpLib libyaml;
        };
    };

    packageMeta = {
      upstream = {
        type = "git-tags";
        url = "https://github.com/yaml/libyaml";

        # `dist-X` duplicates the release tag it was cut from.
        normalise = tag: if pkgs.lib.hasPrefix "dist-" tag then null else tag;

        include =
          version:
          builtins.match "[0-9].*" version != null
          && !(pkgs.lib.hasInfix "rc" version || pkgs.lib.hasInfix "pre" version);
      };
    };
  };

in
{
  inherit canonical;
  aliases = tvpLib.packages.mkAliases {
    inherit
      pname
      versionTable
      canonical
      ;
  };
}

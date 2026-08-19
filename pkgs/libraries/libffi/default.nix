{ pkgs, tvp }:
let
  tvpLib = tvp.lib;

  defs = tvpLib.packages.mkDefs {
    "3.0.9" = {
      builder = ./build-3.0.9.nix;
      base = tvp.bases.default;
      deps = { };
    };

    "3.6.0" = {
      builder = ./build-3.0.9.nix;
      base = tvp.bases.default;
      deps = { };
      opts = {
        reportedVersion = "3.5.2";
      };
    };
  };

  versionTable = tvpLib.packages.mkTable (import ./3.nix { inherit defs; });

  pname = "libffi";

  canonical = tvpLib.packages.mkVersions {
    infra = {
      inherit (pkgs) lib fetchurl;
    };
    inherit pname;
    inherit versionTable;

    extraArgs = {
      mkTests =
        libffi:
        import ./tests {
          inherit pkgs tvpLib libffi;
        };
    };

    packageMeta = {
      upstream = {
        type = "git-tags";
        url = "https://github.com/libffi/libffi";

        normalise = tag: if pkgs.lib.hasPrefix "v" tag then pkgs.lib.removePrefix "v" tag else null;

        include =
          version:
          builtins.match "[0-9].*" version != null
          && !(pkgs.lib.hasInfix "rc" version || pkgs.lib.hasInfix "dev" version);

        unavailable = [
          {
            versions = [
              "3.4.0"
              "3.4.1"
            ];
            reason = "Tagged but never published as a tarball: the GitHub release for each carries no assets at all, where 3.4.2's carries one, and sourceware's archive has neither. Only git-archive snapshots exist, and that is a different artifact.";
          }
        ];
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

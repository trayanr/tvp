{ pkgs, tvp }:
let
  tvpLib = tvp.lib;

  defs = tvpLib.packages.mkDefs {
    "5.0.0" = {
      builder = ./build-5.0.0.nix;
      base = tvp.bases.default;
      deps = { };
    };
  };

  versionTable = tvpLib.packages.mkTable (import ./5.nix { inherit defs; });

  pname = "xz";

  canonical = tvpLib.packages.mkVersions {
    infra = {
      inherit (pkgs) lib fetchurl;
    };
    inherit pname;
    inherit versionTable;

    extraArgs = {
      mkTests =
        xz:
        import ./tests {
          inherit pkgs tvpLib xz;
        };
    };

    packageMeta = {
      upstream = {
        type = "git-tags";
        url = "https://github.com/tukaani-project/xz";

        normalise = tag: if pkgs.lib.hasPrefix "v" tag then pkgs.lib.removePrefix "v" tag else null;

        include =
          version:
          builtins.match "[0-9].*" version != null
          && !(pkgs.lib.hasInfix "alpha" version || pkgs.lib.hasInfix "beta" version);

        unavailable = [
          {
            versions = [
              "5.6.0"
              "5.6.1"
            ];
            reason = "Withdrawn by upstream following CVE-2024-3094: the release tarballs carried a build-time backdoor absent from the git tree. Both are 404 on tukaani.org and on GitHub releases, so there is nothing to package and nothing TVP would put in a signed cache.";
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

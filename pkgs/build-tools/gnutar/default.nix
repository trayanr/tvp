{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  defs = tvpLib.packages.mkDefs {
    "1.32" = {
      builder = ./build-1.32.nix;
      base = tvp.bases.default;
      deps = {
        acl = (
          tvp.lib.packages.withConstraint {
            reason = "tar xattrs.c defines static acl_*_at helpers with three arguments; ACL 2.4 introduces public four-argument functions of the same names. Native tar 1.32 and 1.35 fail with ACL 2.4.0; use the working 2.3 line.";
          } tvp.packages.acl_2_3
        );
        attr = tvp.packages.attr_2;
      };
    };
    "1.35" = {
      builder = ./build-1.35.nix;
      base = tvp.bases.default;
      deps = {
        acl = (
          tvp.lib.packages.withConstraint {
            reason = "tar xattrs.c defines static acl_*_at helpers with three arguments; ACL 2.4 introduces public four-argument functions of the same names. Native tar 1.32 and 1.35 fail with ACL 2.4.0; use the working 2.3 line.";
          } tvp.packages.acl_2_3
        );
        attr = tvp.packages.attr_2;
      };
    };
  };
  versionTable = tvpLib.packages.mkTable [
    {
      def = defs."1.32";
      releases."1.32" = "sha256-0NOuB/EDMjvoCbw+rA3MOG1SxSYkmf4FURrEeIrx/dg=";
      releases."1.33" = "sha256-Zqg0Sx3IOkEdMRvRVH4BduVswxHyjulKMPhNr7PZBn4=";
      releases."1.34" = "sha256-Y769JoecXh7qQ1Lw0DyZH5Zq6z3es8dEXJAlaNVBHSg=";
    }
    {
      def = defs."1.35";
      releases."1.35" = "sha256-TWL/NzQux67XSFNTI5MMfPlKz3HDWRiCsmp+pQ8+3BY=";
    }
  ];
  pname = "gnutar";
  packageArgs = {
    infra = {
      inherit (pkgs) lib fetchurl;
    };
    inherit pname versionTable;
    packageMeta.upstream = import ./upstream.nix;
    extraArgs.mkTests =
      package:
      import ./tests {
        inherit pkgs tvpLib package;
        helpers = [
          {
            bin = "gzip";
            package = tvp.packages.gzip;
            flag = "-z";
          }
          {
            bin = "bzip2";
            package = tvp.packages.bzip2_1;
            flag = "-j";
          }
          {
            bin = "xz";
            package = tvp.packages.xz_5;
            flag = "-J";
          }
          {
            bin = "zstd";
            package = tvp.packages.zstd_1;
            flag = "--zstd";
          }
        ];
      };
  };
  canonical = tvpLib.packages.mkVersions packageArgs;

in
{
  recipes.${pname} = packageArgs;
  inherit canonical;
  aliases = tvpLib.packages.mkAliases { inherit pname versionTable canonical; };
}

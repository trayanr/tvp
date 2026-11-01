{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  defs = tvpLib.packages.mkDefs {
    "20260707" = {
      builder = ./build-20260707.nix;
      base = tvp.bases.default;
      deps = {
        python = tvp.packages.python-build_3;
        ninja = tvp.packages.ninja;
        patchelf = tvp.packages.patchelf;
      };
      opts.revision = "b8becbd4f7979f63ab3542524b2b4d8db2ce3b52";
      # GN disables -Wformat itself while enabling -Werror.
      opts.hardeningDisable = [ "format" ];
      opts.allowWarnings = true;
    };
  };
  pname = "gn";
  versionTable = tvpLib.packages.mkTable [
    {
      def = defs."20260707";
      # Gitiles gzip headers vary between requests; pin the unpacked source tree.
      releases."20260707" = "sha256-LFUIa4E93KbZWqrNTXK1AbNtbI1cOygwkfAsiB4L8dY=";
    }
  ];
  canonical = tvpLib.packages.mkVersions {
    infra = {
      inherit (pkgs) lib fetchzip;
    };
    inherit pname versionTable;
    extraArgs.mkTests =
      package:
      import ./tests {
        inherit tvpLib package;
        pkgs = tvpLib.tests.withBase {
          inherit pkgs;
          base.stdenv = package.stdenv;
        };
      };
  };
in
{
  inherit canonical;
  aliases = tvpLib.packages.mkAliases { inherit pname versionTable canonical; };
}

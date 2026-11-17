{ tvp, ... }:
let
  earlier = import ../../../bases/source-gnu { };
  pname = "gn";
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build-20260707-current.nix;

        opts = {
          revision = "b8becbd4f7979f63ab3542524b2b4d8db2ce3b52";
          hardeningDisable = [ "format" ];
          allowWarnings = true;
        };
      };
      releases = {
        "20260707" = "sha256-LFUIa4E93KbZWqrNTXK1AbNtbI1cOygwkfAsiB4L8dY=";
      };
    }
  ];
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable;
    source = tvp.lib.sources.archive {
      url = "https://gn.googlesource.com/gn/+archive/b8becbd4f7979f63ab3542524b2b4d8db2ce3b52.tar.gz";
      fetch =
        { version, sha256 }:
        import ./native/source.nix {
          inherit (earlier.tools) bash coreutils python;
          curl = tvp.packages.curl;
          caCertificates = tvp.packages.ca-certificates;
          inherit sha256;
          revision = "b8becbd4f7979f63ab3542524b2b4d8db2ce3b52";
        };
      discovery = {
        # GN publishes pinned commits rather than numbered releases.
        type = "git-head";
        url = "https://gn.googlesource.com/gn";
        ref = "refs/heads/main";
        revisions = builtins.mapAttrs (_: release: release.def.opts.revision) versionTable;
      };
    };
    tests = import ./tests;
  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes."gn" = family;
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}

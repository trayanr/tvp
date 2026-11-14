{ pkgs, tvp }:
let
  retained = (import ./legacy.nix { inherit pkgs tvp; }).publicArgs;
  # Explicit earlier closed host, independent of the public compiler indexes.
  compilerHostBase = tvp.baseTiers.full;
  pname = "go-bootstrap";
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build-owned-20171003.nix;
        base = compilerHostBase;
        deps = {
          compiler = tvp.lib.packages.withConstraint {
            category = "construction";
            reason = "Existing closed full-tier C compiler for the C-source Go seed; not public canonical GCC.";
          } compilerHostBase.compiler;
          runtimeShell = tvp.lib.packages.withConstraint {
            category = "construction";
            reason = "Exact earlier Bash launcher provider for the C-source Go seed.";
          } compilerHostBase.shell;
          runtimeLibc = tvp.lib.packages.withConstraint {
            category = "construction";
            reason = "Exact earlier target libc of the closed full-tier compiler for the C-source Go seed.";
          } compilerHostBase.compiler.libc;
        };
        opts = {
          cStandard = "gnu17";
          goOS = "linux";
          goArch = "amd64";
          reportedVersion = "go1.4-bootstrap-20170531";
          compiledRoot = "/tvp/go-bootstrap";
          cgo = false;
        };
      };
      releases."20171003" = "sha256-9P9bXrOjyuHJk3I/PqtRnFuuGIZrXl+W/hEC8MtcPlI=";
    }
  ];
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable;
    packageMeta = retained.packageMeta or { };
    source =
      { version, sha256 }:
      pkgs.fetchurl {
        url = "https://dl.google.com/go/go1.4-bootstrap-${version}.tar.gz";
        inherit sha256;
      };
    tests = import ./tests/installed.nix;
  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes.go-bootstrap = family // {
    constructionRecipe = retained;
  };
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}

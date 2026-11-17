{ tvp, ... }:
let
  # Explicit earlier closed host, independent of the public compiler indexes.
  compilerHostBase = tvp.bases.gcc_16.full;
  pname = "go-bootstrap";
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build-owned-20171003.nix;
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
    source = tvp.lib.sources.directory {
      url = "https://dl.google.com/go/";
      archive = "go1.4-bootstrap-{version}.tar.gz";
      discovery = {
        type = "directory-index";
        # The download bucket has no public listing. Go's installation guide
        # publishes the recommended dated C-bootstrap archive instead.
        url = "https://go.dev/doc/install/source";
        pattern = ''href="https://dl[.]google[.]com/go/go1[.]4-bootstrap-[0-9]{8}[.]tar[.]gz"'';
        scope = "Currently documented C-bootstrap archives; historical snapshots are not enumerated.";
        normalise =
          filename:
          let
            match = builtins.match ''href="https://dl[.]google[.]com/go/go1[.]4-bootstrap-([0-9]{8})[.]tar[.]gz"'' filename;
          in
          if match == null then null else builtins.head match;
      };
    };
    tests = import ./tests/installed.nix;
  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes.go-bootstrap = family;
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}

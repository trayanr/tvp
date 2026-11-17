{ tvp, ... }:
let
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build.nix;
        patches = [
          {
            file = ./patches/subprocess-shell.patch;
            reason = "Store-layout adaptation: subprocess shell commands use the declared Bash instead of the host /bin/sh, which is absent in Nix build sandboxes.";
          }
        ];
      };
      releases."3.12.5" = "sha256-+oouEsXmILCfU+ZbzYdVDS5aHi4Ev4upkdzFUROHY5c=";
    }
  ];
  pname = "python-minimal";
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable;
    source = tvp.lib.sources.archive {
      url = version: "https://www.python.org/ftp/python/${version}/Python-${version}.tar.xz";
      discovery = {
        type = "git-tags";
        url = "https://github.com/python/cpython";
        prefix = "v";
        include = version: builtins.match "[0-9]+(\\.[0-9]+)+" version != null;
      };
    };
    tests = import ./tests/installed.nix;
    testDeps.glibc = tvp.packages.glibc_2;
  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes.python-minimal = family;
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}

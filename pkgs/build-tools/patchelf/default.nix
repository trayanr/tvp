{ tvp, ... }:
let
  full = tvp.bases.gcc_16.full;
  earlier = import ../../../bases/source-gnu { };
  pname = "patchelf";
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build-0.19.2-native.nix;
        deps = {
          cxxRuntime = tvp.lib.packages.withConstraint {
            category = "construction";
            reason = "Exact full source-GNU C++ runtime selected by the current driver; the public compiler consumes Patchelf.";
          } earlier.toolchain.runtime;
        };
      };
      releases = {
        "0.19.2" = "sha256-1K2aTlxongkRnOLzCpSw6LT5jHhZASPqIWZeNMaSiAE=";
      };
    }
  ];
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable;
    source = tvp.lib.sources.archive {
      url =
        version:
        "https://github.com/NixOS/patchelf/releases/download/${version}/patchelf-${version}.tar.bz2";
      discovery = {
        type = "git-tags";
        url = "https://github.com/NixOS/patchelf";
        include = version: builtins.match "[0-9]+(\\.[0-9]+)+" version != null;
      };
    };
    tests = import ./tests;
  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes."patchelf" = family;
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}

{ pkgs, gcc }:
let
  upstream = gcc.tvp.upstream;
  # Historical two- and four-component releases are intentional, as are
  # duplicate visible names. Only complete stable release links count.
  fixture = ''
    <a href="../">Parent Directory</a>
    <a href="egcs-1.1.2/">egcs-1.1.2/</a>
    <a href="gcc-2.95/">gcc-2.95/</a>
    <a href="gcc-2.95.2.1/">gcc-2.95.2.1/</a>
    <a href="gcc-13.3.0/">gcc-13.3.0/</a>
    <a href="gcc-13.3.0/">gcc-13.3.0/</a>
    <a href="gcc-14.1.0-rc1/">gcc-14.1.0-rc1/</a>
    <a href="gcc-14.1.0RC1/">gcc-14.1.0RC1/</a>
    <a href="gcc-14-20240414/">gcc-14-20240414/</a>
    <a href="snapshots/gcc-14.1.0/">gcc-14.1.0/</a>
    <a href="not-gcc-14.1.0/">gcc-14.1.0/</a>
    <a href="gcc-14.1.0/extra">gcc-14.1.0/</a>
    <a href="gcc-14.1.0.tar.xz">gcc-14.1.0.tar.xz</a>
    <a href="gcc-14/">gcc-14/</a>
    <a href="gcc-14..1/">gcc-14..1/</a>
    <a href="README">README</a>
  '';
  links = map builtins.head (
    builtins.filter builtins.isList (builtins.split "(${upstream.pattern})" fixture)
  );
  versions = pkgs.lib.sort builtins.lessThan (
    pkgs.lib.unique (builtins.filter (v: v != null) (map upstream.normalise links))
  );
in
assert
  versions == [
    "13.3.0"
    "2.95"
    "2.95.2.1"
  ];
pkgs.runCommand "gcc-release-index-fixtures"
  {
    passthru = {
      package = gcc;
      testName = "tracker";
    };
  }
  ''
    set -euo pipefail
    mkdir -p "$out"
    grep -oE ${pkgs.lib.escapeShellArg upstream.pattern} ${pkgs.writeText "gcc-release-index.html" fixture} > "$out/links"
    # Check GNU grep extraction agrees with the links normalized above.
    diff -u ${
      pkgs.writeText "gcc-release-links.txt" (pkgs.lib.concatStringsSep "\n" links + "\n")
    } "$out/links"
    echo 'PASS stable two/three/four-component directories, deduplication and rejected prerelease/snapshot/junk entries' > "$out/results.log"
  ''

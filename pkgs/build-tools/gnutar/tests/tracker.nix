{ pkgs }:
let
  upstream = import ../upstream.nix;
  archives = builtins.fromJSON (builtins.readFile ./upstream-archives.json);
  versions = builtins.fromJSON (builtins.readFile ./upstream-versions.json);
  rejected = [
    "tar-1.35.tar.xz.sig"
    "tar-1.35.tar.gz.sig"
    "tar-1.35.tar.xz.backup"
    "prefix-tar-1.35.tar.xz"
    "tar-1.35.tar.xz-suffix"
    "tar-1.35-rc1.tar.xz"
    "tar-1.35.90-alpha.tar.gz"
    "tar-1.35.tar.zip"
    "tar-1.35.shar.gz"
    "tar-1.35.cpio.gz"
    "tar-1.35.diff.gz"
    "tar-1.35.patch"
    "tar-1.35.msdos.tar.gz"
    "tar-1.35.tar.gz/"
    "README"
    "tar-1.tar.xz"
    "tar-.tar"
    "tar-1..35.tar.gz"
    "tar-1.35.tar.xz?download=1"
    "tar-1.35.tar.xz#fragment"
  ];
  found = pkgs.lib.unique (map upstream.normalise archives);
  fixture = pkgs.writeText "gnutar-index-fixture.html" ''
    <a href="tar-1.13.tar">tar-1.13.tar</a>
    <a href="tar-1.11.8.tar.gz">tar-1.11.8.tar.gz</a>
    <a href="tar-1.35.tar.xz.sig">tar-1.35.tar.xz.sig</a>
    <a href="prefix-tar-1.35.tar.xz">prefix-tar-1.35.tar.xz</a>
    <a href="tar-1.35-rc1.tar.xz">tar-1.35-rc1.tar.xz</a>
  '';
in
assert builtins.length archives == 67;
assert builtins.length found == 28;
assert pkgs.lib.sort builtins.lessThan found == pkgs.lib.sort builtins.lessThan versions;
assert builtins.all (name: upstream.normalise name == null) rejected;
pkgs.runCommand "gnutar-upstream-fixtures" { } ''
  set -euo pipefail
  mkdir -p "$out"
  grep -oE ${pkgs.lib.escapeShellArg upstream.pattern} ${fixture} > "$out/tokens"
  # Complete hrefs and complete visible names, including rejected suffixes.
  for name in tar-1.13.tar tar-1.11.8.tar.gz tar-1.35.tar.xz.sig prefix-tar-1.35.tar.xz tar-1.35-rc1.tar.xz; do
    test "$(grep -cxF "$name" "$out/tokens")" = 2
  done
  printf '%s\n' 'PASS 67 archive variants / 28 numeric releases; strict rejection and format deduplication' > "$out/results.log"
''

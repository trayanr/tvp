{ pkgs, package }:
let
  normalise = package.tvp.upstream.normalise;
  accepted = {
    "v3.1.0" = "3.1.0";
    "v4.4.36" = "4.4.36";
    "v4.5.0" = "4.5.0";
    "v4.5.1" = "4.5.1";
    "v4.5.2" = "4.5.2";
    "v12.34.56" = "12.34.56";
  };
  rejected = [
    "4.5.2"
    "v4.5"
    "v4.5.2.1"
    "v4.5.2-rc1"
    "v4.5.2rc1"
    "v4.5.2-dev"
    "v4.5.2+meta"
    "prefixv4.5.2"
    "v4.5.2suffix"
    " v4.5.2"
    "v4.5.2\n"
    "v4x5x2"
    "develop"
    "v4.5.2^{}"
    ""
  ];
  valid =
    pkgs.lib.all (tag: normalise tag == accepted.${tag}) (builtins.attrNames accepted)
    && pkgs.lib.all (tag: normalise tag == null) rejected;
in
assert valid;
{
  upstream-fixtures =
    pkgs.runCommand "libxcrypt-${package.version}-upstream-fixtures"
      {
        nativeBuildInputs = [
          pkgs.gnused
          pkgs.coreutils
        ];
        passthru = {
          inherit package;
          testName = "upstream-fixtures";
        };
      }
      ''
        set -euo pipefail
        mkdir -p "$out"
        # The existing git-tags tool strips peeled refs before normalisation,
        # then deduplicates. The normalizer itself requires a complete tag.
        printf '%s\n' \
          'a refs/tags/v4.5.2' 'b refs/tags/v4.5.2^{}' \
          'c refs/tags/v4.5.1' 'd refs/tags/v4.5.1^{}' \
          | sed 's|.*refs/tags/||; s|\^{}$||' | sort -u > "$out/tags"
        printf '%s\n' v4.5.1 v4.5.2 > expected
        diff -u expected "$out/tags"
        echo 'PASS exact full-match normalization/rejections and peeled-ref deduplication' | tee "$out/results.log"
      '';
}

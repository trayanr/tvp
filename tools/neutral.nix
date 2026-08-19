# Snapshots every canonical derivation path, and diffs two snapshots.
#
# Structural changes — moving files, splitting them, renaming a builder, adding
# passthru, reformatting — are all supposed to compute the same derivations.
# Asserting that is worthless; this is how it gets proved.
#
# Compares by joining on the attribute name, never by counting: versions added
# between two snapshots are additions, not regressions, and a diff that cannot
# tell those apart reports both as failures.
{
  lib,
  writeShellApplication,
  writeText,
  coreutils,
  jq,

  packages,
  tvpLib,
}:
let
  canonical = lib.filterAttrs (
    name: p:
    (p.pname or "") != ""
    && (p.version or "") != ""
    && name == tvpLib.versions.attrName p.pname p.version
  ) packages;

  snapshot = writeText "tvp-drv-snapshot.json" (
    builtins.toJSON (
      lib.mapAttrs (_: p: {
        drv = builtins.unsafeDiscardStringContext p.drvPath;
        out = builtins.unsafeDiscardStringContext p.outPath;
      }) canonical
    )
  );
in
writeShellApplication {
  name = "tvp-neutral";
  runtimeInputs = [
    coreutils
    jq
  ];
  text = ''
    # join and comm compare bytes; sort must not use locale collation, or
    # they silently disagree on any name containing - or _.
    export LC_ALL=C
    key=drv
    if [ "''${1:-}" = "--out" ]; then key=out; shift; fi

    emit() { jq -r --arg k "$key" 'to_entries[] | "\(.key) \(.value[$k])"' ${snapshot} | sort; }

    case "''${1:-}" in
      "")
        # A source-URL change moves drvPath while leaving outPath identical, so
        # --out is the right comparison there and drv is a false positive.
        echo "usage: tvp-neutral [--out] save <file>" >&2
        echo "       tvp-neutral [--out] diff <before-file>" >&2
        exit 2
        ;;
      save)
        [ -n "''${2:-}" ] || { echo "tvp-neutral: save needs a file" >&2; exit 2; }
        emit > "$2"
        printf 'saved %s attributes to %s\n' "$(wc -l < "$2")" "$2"
        ;;
      diff)
        [ -r "''${2:-}" ] || { echo "tvp-neutral: cannot read ''${2:-<none>}" >&2; exit 2; }
        before=$2
        after=$(mktemp); emit > "$after"

        changed=$(join "$before" "$after" -o 0,1.2,2.2 | awk '$2 != $3 {print "  " $1 "\n    before " $2 "\n    after  " $3}')
        common=$(join "$before" "$after" | wc -l)
        added=$(comm -13 <(cut -d' ' -f1 "$before") <(cut -d' ' -f1 "$after") | wc -l)
        gone=$(comm -23 <(cut -d' ' -f1 "$before") <(cut -d' ' -f1 "$after") | wc -l)

        printf 'compared %s common attributes (%s added, %s removed)\n\n' "$common" "$added" "$gone"
        if [ -z "$changed" ]; then
          printf 'unchanged: every common attribute computes the same %s\n' "$key"
        else
          printf 'CHANGED:\n%s\n' "$changed"
          exit 1
        fi
        ;;
      *)
        echo "tvp-neutral: unknown command $1" >&2; exit 2
        ;;
    esac
  '';
}

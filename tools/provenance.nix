# Reports how much of each package's runtime closure is built by TVP.
{
  lib,
  writeShellApplication,
  writeText,
  coreutils,
  gawk,
  jq,

  packages,
  tvpLib,
}:
let
  entry =
    name: p:
    let
      pname = p.pname or "";
      version = p.version or "";
    in
    {
      inherit name pname version;
      canonical = pname != "" && version != "" && name == tvpLib.versions.attrName pname version;
      # Context discarded, or referencing a path would make this script depend on
      # building the entire repository.
      out = builtins.unsafeDiscardStringContext p.outPath;
    };

  # A broken package has no closure to attribute, and forcing outPath throws.
  entries = lib.mapAttrsToList entry (
    lib.filterAttrs (_: p: (p.tvp.status.level or "ok") != "broken") packages
  );

  # Trailing newline on every line, or `read` drops the last entry.
  manifest = writeText "tvp-provenance-manifest" (
    lib.concatMapStrings (
      e: "${e.name}\t${if e.canonical then "canonical" else "alias"}\t${e.out}\n"
    ) entries
  );
in
writeShellApplication {
  name = "tvp-provenance";
  runtimeInputs = [
    coreutils
    gawk
    jq
  ];
  text = ''
    manifest=${manifest}
    json=0
    [ "''${1:-}" = "--json" ] && json=1

    work=$(mktemp -d)
    trap 'rm -rf "$work"' EXIT

    cut -f3 "$manifest" | sort -u > "$work/tvp-paths"

    : > "$work/rows"
    : > "$work/unbuilt"
    : > "$work/pkgs.jsonl"
    : > "$work/foreign-all"
    : > "$work/owned-all"

    while IFS=$'\t' read -r name kind out; do
      [ "$kind" = "canonical" ] || continue

      if ! nix path-info "$out" >/dev/null 2>&1; then
        printf '%s\n' "$name" >> "$work/unbuilt"
        continue
      fi

      nix path-info -r "$out" 2>/dev/null | sort -u > "$work/closure"

      comm -12 "$work/closure" "$work/tvp-paths" \
        | sed 's|^/nix/store/[a-z0-9]*-||' | sort -u > "$work/owned"
      comm -23 "$work/closure" "$work/tvp-paths" \
        | sed 's|^/nix/store/[a-z0-9]*-||' | sort -u > "$work/foreign"

      owned=$(wc -l < "$work/owned")
      total=$(wc -l < "$work/closure")

      cat "$work/foreign" >> "$work/foreign-all"
      cat "$work/owned" >> "$work/owned-all"
      printf '%s\t%s\t%s\n' "$name" "$owned" "$total" >> "$work/rows"

      jq -n -R -s \
        --arg package "$name" --argjson owned "$owned" --argjson total "$total" \
        --rawfile foreignRaw "$work/foreign" --rawfile ownedRaw "$work/owned" \
        '{ package: $package, owned: $owned, total: $total,
           percent: ($owned * 1000 / $total | round / 10),
           tvp: ($ownedRaw | split("\n") | map(select(length > 0))),
           foreign: ($foreignRaw | split("\n") | map(select(length > 0))) }' \
        < /dev/null >> "$work/pkgs.jsonl"
    done < "$manifest"

    # How many packages need each foreign path: the order to take ownership in.
    sort "$work/foreign-all" | uniq -c | sort -k1,1rn -k2,2 > "$work/foreign-ranked"

    if [ "$json" = 1 ]; then
      jq -n -s \
        --slurpfile pkgs "$work/pkgs.jsonl" \
        --rawfile unbuiltRaw "$work/unbuilt" \
        --rawfile rankedRaw "$work/foreign-ranked" \
        '{ packages: $pkgs,
           unbuilt: ($unbuiltRaw | split("\n") | map(select(length > 0))),
           foreign: ($rankedRaw | split("\n") | map(select(length > 0))
                     | map(capture("^\\s*(?<needed_by>[0-9]+)\\s+(?<name>.+)$"))
                     | map({ name: .name, needed_by: (.needed_by|tonumber) })) }' \
        < /dev/null
      exit 0
    fi

    printf '%-20s %7s %7s %8s\n' PACKAGE OWNED TOTAL PERCENT
    awk -F'\t' '{ printf "%-20s %7d %7d %7.1f%%\n", $1, $2, $3, ($3 ? $2*100/$3 : 0) }' "$work/rows"

    echo
    sort -u "$work/owned-all" > "$work/owned-distinct"
    printf 'BUILT BY TVP (%s)\n' "$(wc -l < "$work/owned-distinct")"
    sed 's/^/  /' "$work/owned-distinct"

    echo
    printf 'NOT BUILT BY TVP (%s), by how many packages need them\n' \
      "$(wc -l < "$work/foreign-ranked")"
    awk '{ n = $1; $1 = ""; sub(/^ /, ""); printf "  %3d  %s\n", n, $0 }' "$work/foreign-ranked"

    if [ -s "$work/unbuilt" ]; then
      echo
      echo "NOT BUILT (no closure to inspect — figures above exclude these):"
      sed 's/^/  /' "$work/unbuilt"
    fi
  '';
}

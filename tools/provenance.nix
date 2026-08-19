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
      drv = builtins.unsafeDiscardStringContext p.drvPath;
    };

  # A broken package has no closure to attribute, and forcing outPath throws.
  entries = lib.mapAttrsToList entry (
    lib.filterAttrs (_: p: (p.tvp.status.level or "ok") != "broken") packages
  );

  # Trailing newline on every line, or `read` drops the last entry.
  manifest = writeText "tvp-provenance-manifest" (
    lib.concatMapStrings (
      e: "${e.name}\t${if e.canonical then "canonical" else "alias"}\t${e.out}\t${e.drv}\n"
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
    : > "$work/build-foreign-all"

    # One batched pass, so directory-ness is decided once for the whole
    # catalogue rather than per package. A directory is a package; the rest are
    # tarballs, patches and setup hooks.
    awk -F'\t' '$2 == "canonical" { print $4 }' "$manifest" | sort -u > "$work/drvs"
    xargs -r -a "$work/drvs" nix-store -qR --include-outputs 2>/dev/null \
      | grep -v '\.drv$' | sort -u > "$work/build-union" || true
    comm -23 "$work/build-union" "$work/tvp-paths" \
      | while read -r p; do
          if [ -d "$p" ]; then printf '%s\n' "$p"; fi
        done \
      | sort -u > "$work/build-foreign-paths"

    while IFS=$'\t' read -r name kind out drv; do
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

      # Deduped by name, not by path: one name can sit at several hashes.
      nix-store -qR --include-outputs "$drv" 2>/dev/null \
        | grep -v '\.drv$' | sort -u > "$work/bclosure" || true
      comm -12 "$work/bclosure" "$work/build-foreign-paths" \
        | sed 's|^/nix/store/[a-z0-9]*-||' | sort -u >> "$work/build-foreign-all"

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

    # At build time most of the substrate is needed by everything, and a count
    # equal to the catalogue ranks nothing. Only the entries that discriminate
    # are a worklist; the rest are reported as a total.
    npkgs=$(wc -l < "$work/rows")
    sort "$work/build-foreign-all" | uniq -c | sort -k1,1rn -k2,2 > "$work/build-ranked"
    awk -v n="$npkgs" '$1 != n' "$work/build-ranked" > "$work/build-tail"
    universal=$(awk -v n="$npkgs" '$1 == n' "$work/build-ranked" | wc -l)

    if [ "$json" = 1 ]; then
      jq -n -s \
        --slurpfile pkgs "$work/pkgs.jsonl" \
        --rawfile unbuiltRaw "$work/unbuilt" \
        --rawfile rankedRaw "$work/foreign-ranked" \
        --rawfile buildRaw "$work/build-tail" \
        --argjson universal "$universal" \
        'def ranked: split("\n") | map(select(length > 0))
                     | map(capture("^\\s*(?<needed_by>[0-9]+)\\s+(?<name>.+)$"))
                     | map({ name: .name, needed_by: (.needed_by|tonumber) });
         { packages: $pkgs,
           unbuilt: ($unbuiltRaw | split("\n") | map(select(length > 0))),
           foreign: ($rankedRaw | ranked),
           foreignBuild: { universal: $universal, ranked: ($buildRaw | ranked) } }' \
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

    echo
    printf 'FOREIGN AT BUILD TIME (%s), by how many packages need them\n' \
      "$(wc -l < "$work/build-tail")"
    printf '  %s more are needed by all %s, and are omitted: that is the substrate.\n' \
      "$universal" "$npkgs"
    awk '{ n = $1; $1 = ""; sub(/^ /, ""); printf "  %3d  %s\n", n, $0 }' "$work/build-tail"

    if [ -s "$work/unbuilt" ]; then
      echo
      echo "NOT BUILT (no closure to inspect — figures above exclude these):"
      sed 's/^/  /' "$work/unbuilt"
    fi
  '';
}

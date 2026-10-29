# Reports how much of each package's runtime closure is built by TVP, and what
# building the catalogue reaches beyond that.
{
  lib,
  writeShellApplication,
  writeText,
  coreutils,
  gawk,
  jq,

  packages,
  variantPackages ? { },
  registry,
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
      variant = p.tvp.variant or null;
      source = tvpLib.provenance.sourceKind p;
      blob = p.tvp.blob or null;
      base = p.tvp.base or null;
      # Context discarded, or referencing a path would make this script depend on
      # building the entire repository.
      out = builtins.unsafeDiscardStringContext p.outPath;
      drv = builtins.unsafeDiscardStringContext p.drvPath;
    };

  # A broken package has no closure to attribute, and forcing outPath throws.
  entries = lib.mapAttrsToList entry (
    lib.filterAttrs (_: p: (p.tvp.status.level or "ok") != "broken") (packages // variantPackages)
  );

  # Trailing newline on every line, or `read` drops the last entry.
  manifest = writeText "tvp-provenance-manifest" (
    lib.concatMapStrings (
      e:
      "${e.name}\t${
        if e.variant != null then
          "variant"
        else if e.canonical then
          "canonical"
        else
          "alias"
      }\t${e.out}\t${e.drv}\t${e.source}\n"
    ) entries
  );
  registration = writeText "tvp-registration.json" (builtins.toJSON registry);
  metadata = writeText "tvp-provenance-metadata.json" (builtins.toJSON entries);

  # Every closure below is walked here rather than by a nix invocation per
  # package. The three queries in the script return the whole graph once, and a
  # thousand traversals of it cost less than a single process start.
  runtimeAwk = writeText "tvp-provenance-runtime.awk" ''
    function nm(p,   s) { s = p; sub(/^\/nix\/store\/[a-z0-9]*-/, "", s); return s }
    BEGIN { FS = "\t" }
    FILENAME ~ /tvp-paths$/ { tvp[$0] = 1; next }
    FILENAME ~ /source-kinds$/ { if (!($1 in source)) source[$1] = $2; next }
    FILENAME ~ /refs$/ { ref[$1, ++rn[$1]] = $2; next }
    {
      split("", seen); split("", own); split("", alien); split("", alienPaths); split("", binary); split("", mixed)
      top = 1; stack[1] = $2; seen[$2] = 1; total = 0; owned = 0
      while (top > 0) {
        p = stack[top--]
        total++
        if (p in tvp) { owned++; own[nm(p)] = 1 } else { alien[nm(p)] = 1; alienPaths[p] = 1 }
        if (source[p] == "binary") binary[nm(p)] = 1
        if (source[p] == "mixed") mixed[nm(p)] = 1
        for (i = 1; i <= rn[p]; i++)
          if (!(ref[p, i] in seen)) { seen[ref[p, i]] = 1; stack[++top] = ref[p, i] }
      }
      o = ""; for (m in own)   { o = o (o == "" ? "" : " ") m; ownedAll[m] = 1 }
      f = ""; for (m in alien) { f = f (f == "" ? "" : " ") m; tally[m]++ }
      b = ""; for (m in binary) b = b (b == "" ? "" : " ") m
      x = ""; for (m in mixed) x = x (x == "" ? "" : " ") m
      a = ""; for (m in alienPaths) a = a (a == "" ? "" : " ") m
      printf "%s\t%d\t%d\t%s\t%s\t%s\t%s\t%s\t%s\n", $1, owned, total, o, f, b, x, $3, a
    }
    END {
      for (m in ownedAll) print m > ownedFile
      for (m in tally) printf "%d\t%s\n", tally[m], m > tallyFile
    }
  '';

  buildAwk = writeText "tvp-provenance-build.awk" ''
    function nm(p,   s) { s = p; sub(/^\/nix\/store\/[a-z0-9]*-/, "", s); return s }
    BEGIN { FS = "\t" }
    FILENAME ~ /candidates$/ { want[$0] = nm($0); next }
    FILENAME ~ /edges$/ {
      if ($1 == "D") kid[$2, ++kn[$2]] = $3
      else if ($3 in want) out[$2, ++on[$2]] = $3
      next
    }
    {
      split("", seen); split("", reached); split("", got)
      top = 1; stack[1] = $2; seen[$2] = 1
      while (top > 0) {
        d = stack[top--]
        for (i = 1; i <= on[d]; i++) reached[out[d, i]] = 1
        for (i = 1; i <= kn[d]; i++)
          if (!(kid[d, i] in seen)) { seen[kid[d, i]] = 1; stack[++top] = kid[d, i] }
      }
      # Deduped by name, not by path: one name can sit at several hashes.
      for (p in reached) got[want[p]] = 1
      for (m in got) tally[m]++
      roots++
    }
    END { for (m in tally) printf "%d\t%s\n", tally[m], m }
  '';
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

    jq -r '.[].path' ${registration} | sort -u > "$work/tvp-paths"
    jq -r '.[] | [.path, .source] | @tsv' ${registration} > "$work/source-kinds"
    awk -F'\t' '$2 == "canonical" { print $3 }' "$manifest" | sort -u > "$work/outs"
    awk -F'\t' '$2 == "canonical" { print $4 }' "$manifest" | sort -u > "$work/drvs"

    # Query one. nix path-info aborts on the first unrealised path, so the
    # unbuilt set has to be known before the graph can be asked for.
    # --stdin throughout: a large enough catalogue exceeds argv.
    nix-store --check-validity --print-invalid --stdin < "$work/outs" 2> /dev/null \
      | sort -u > "$work/invalid" || true
    comm -23 "$work/outs" "$work/invalid" > "$work/valid"

    awk -F'\t' 'NR == FNR { bad[$0] = 1; next }
                $2 == "canonical" && ($3 in bad) { print $1 }' \
      "$work/invalid" "$manifest" > "$work/unbuilt"

    # Query two: every runtime reference edge in the catalogue.
    nix path-info --json -r --stdin < "$work/valid" 2> /dev/null > "$work/refs.json"
    jq -r 'to_entries[] | .key as $k | .value.references[] | select(. != $k) | "\($k)\t\(.)"' \
      "$work/refs.json" > "$work/refs"

    awk -F'\t' 'NR == FNR { ok[$0] = 1; next }
                $2 == "canonical" && ($3 in ok) { print $1 "\t" $3 "\t" $5 }' \
      "$work/valid" "$manifest" > "$work/roots"

    awk -v ownedFile="$work/owned-all" -v tallyFile="$work/foreign-tally" \
      -f ${runtimeAwk} "$work/tvp-paths" "$work/source-kinds" "$work/refs" "$work/roots" > "$work/rows"

    # Query three: every derivation in the build graph, with its inputs. The
    # field moved from inputDrvs to inputs.drvs, and output paths from absolute
    # to store-relative, so both spellings are accepted. A fixed-output
    # derivation states a hash instead of a path; those are all fetched
    # tarballs, which are dropped a few lines below for not being directories.
    nix derivation show -r --stdin < "$work/drvs" 2> /dev/null > "$work/drvs.json"
    jq -r '
      def abs: if startswith("/") then . else "/nix/store/" + . end;
      (.derivations // .) | to_entries[] | (.key | abs) as $k
      | ((.value.inputs.drvs // .value.inputDrvs // {}) | keys[] | "D\t\($k)\t\(. | abs)"),
        (.value.outputs | to_entries[] | select(.value.path != null)
         | "O\t\($k)\t\(.value.path | abs)")
    ' "$work/drvs.json" > "$work/edges"

    # A directory is a package; the rest are tarballs, patches and setup hooks.
    awk -F'\t' '$1 == "O" { print $3 }' "$work/edges" | sort -u > "$work/declared"
    comm -23 "$work/declared" "$work/tvp-paths" \
      | while read -r p; do
          if [ -d "$p" ]; then printf '%s\n' "$p"; fi
        done > "$work/candidates"

    awk -F'\t' 'NR == FNR { ok[$0] = 1; next }
                $2 == "canonical" && ($3 in ok) { print $1 "\t" $4 }' \
      "$work/valid" "$manifest" > "$work/build-roots"

    awk -f ${buildAwk} "$work/candidates" "$work/edges" "$work/build-roots" \
      > "$work/build-tally"

    # How many packages need each foreign path: the order to take ownership in.
    sort -k1,1rn -k2,2 "$work/foreign-tally" > "$work/foreign-ranked"

    # At build time most of the substrate is needed by everything, and a count
    # equal to the catalogue ranks nothing. Those entries are still listed —
    # naming them once as a group is what a tie is, and an inventory that omits
    # them cannot answer where a given package sits.
    npkgs=$(wc -l < "$work/rows")
    sort -k1,1rn -k2,2 "$work/build-tally" > "$work/build-ranked"
    awk -F'\t' -v n="$npkgs" '$1 != n' "$work/build-ranked" > "$work/build-tail"
    awk -F'\t' -v n="$npkgs" '$1 == n { print $2 }' "$work/build-ranked" \
      > "$work/build-universal"

    if [ "$json" = 1 ]; then
      jq -n -R \
        --rawfile rowsRaw "$work/rows" \
        --rawfile unbuiltRaw "$work/unbuilt" \
        --rawfile rankedRaw "$work/foreign-ranked" \
        --rawfile buildRaw "$work/build-tail" \
        --rawfile universalRaw "$work/build-universal" \
        --argjson npkgs "$npkgs" \
        --slurpfile metadata ${metadata} \
        --slurpfile registration ${registration} \
        'def lines: split("\n") | map(select(length > 0));
         def ranked: lines | map(split("\t"))
                     | map({ name: .[1], needed_by: (.[0] | tonumber) });
         def words: if . == "" then [] else (split(" ") | sort) end;
         { packages: ($rowsRaw | lines | map(split("\t"))
             | map({ package: .[0], owned: (.[1] | tonumber), total: (.[2] | tonumber),
                     percent: ((.[1] | tonumber) * 1000 / (.[2] | tonumber) | round / 10),
                     tvp: (.[3] | words), foreign: (.[4] | words), source: .[7],
                     foreignPaths: (.[8] | words),
                     runtimeBoundaries: {binary: (.[5] | words), mixed: (.[6] | words)} })),
           declarations: ($metadata[0] | map({package: .name, base, source, blob})),
           registration: {paths: ($registration[0] | map(.path) | unique | length)},
           unbuilt: ($unbuiltRaw | lines),
           foreign: ($rankedRaw | ranked),
           foreignBuild: {
             ranked: ($buildRaw | ranked),
             universal: { needed_by: $npkgs, names: ($universalRaw | lines) } } }'
      exit 0
    fi

    printf '%-20s %10s %7s %8s %s\n' PACKAGE REGISTERED TOTAL PERCENT SOURCE
    awk -F'\t' '{ printf "%-20s %10d %7d %7.1f%% %s\n", $1, $2, $3, ($3 ? $2*100/$3 : 0), $8 }' \
      "$work/rows"

    echo
    sort -u "$work/owned-all" > "$work/owned-distinct"
    printf 'REGISTERED IN TVP (%s); source/binary provenance is reported separately\n' "$(wc -l < "$work/owned-distinct")"
    sed 's/^/  /' "$work/owned-distinct"

    echo
    printf 'OUTSIDE TVP REGISTRATION (%s), by how many packages need them\n' \
      "$(wc -l < "$work/foreign-ranked")"
    awk -F'\t' '{ printf "  %3d  %s\n", $1, $2 }' "$work/foreign-ranked"

    echo
    printf 'FOREIGN AT BUILD TIME (%s), by how many packages need them\n' \
      "$(wc -l < "$work/build-ranked")"
    awk -F'\t' '{ printf "  %4d  %s\n", $1, $2 }' "$work/build-tail"
    if [ -s "$work/build-universal" ]; then
      printf '  %4d  the substrate — %s entries, tied, so named rather than ranked:\n' \
        "$npkgs" "$(wc -l < "$work/build-universal")"
      fmt -w 72 "$work/build-universal" | sed 's/^/          /'
    fi

    if [ -s "$work/unbuilt" ]; then
      echo
      echo "NOT BUILT (no closure to inspect — figures above exclude these):"
      sed 's/^/  /' "$work/unbuilt"
    fi
  '';
}

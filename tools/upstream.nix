# Reports which upstream releases exist that TVP has not packaged.
#
# Not hermetic: the answer depends on the network at query time, so this is a
# command and never a check.
{
  lib,
  writeShellApplication,
  writeText,
  coreutils,
  curl,
  git,
  gnugrep,
  gnused,
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
    && p ? tvp
    && p.tvp ? upstream
  ) packages;

  byPname = lib.groupBy (p: p.pname) (lib.attrValues canonical);

  # normalise/include are functions and cannot be serialised; they are applied
  # by evaluating the flake, so only their inputs travel through this file.
  describe = pname: ps: {
    inherit pname;
    attr = tvpLib.versions.attrName pname (builtins.head ps).version;
    versions = lib.sort (a: b: builtins.compareVersions a b < 0) (map (p: p.version) ps);
    upstream = removeAttrs (builtins.head ps).tvp.upstream [
      "normalise"
      "include"
    ];
  };

  manifest = writeText "tvp-upstream-manifest.json" (
    builtins.toJSON (lib.mapAttrsToList describe byPname)
  );
in
writeShellApplication {
  name = "tvp-upstream";
  runtimeInputs = [
    coreutils
    curl
    git
    gnugrep
    gnused
    jq
  ];
  text = ''
    manifest=${manifest}
    flake="."
    filters=()

    while [ $# -gt 0 ]; do
      case "$1" in
        --flake) flake="$2"; shift 2 ;;
        -h|--help)
          echo "usage: tvp-upstream [--flake REF] [PACKAGE...]"
          exit 0
          ;;
        -*) echo "tvp-upstream: unknown option '$1'" >&2; exit 2 ;;
        *) filters+=("$1"); shift ;;
      esac
    done

    known=$(jq -r '.[].pname' "$manifest" | sort)
    if [ ''${#filters[@]} -gt 0 ]; then
      for f in "''${filters[@]}"; do
        if ! grep -qxF "$f" <<< "$known"; then
          echo "tvp-upstream: no package '$f'; known: $(tr '\n' ' ' <<< "$known")" >&2
          exit 2
        fi
      done
      select=$(printf '%s\n' "''${filters[@]}" | jq -R -s 'split("\n") | map(select(length > 0))')
    else
      select=null
    fi

    system=$(nix eval --raw --impure --expr 'builtins.currentSystem')

    work=$(mktemp -d)
    trap 'rm -rf "$work"' EXIT

    fetch_raw() {
      local type=$1 url=$2 subdir=$3 pattern=$4
      case "$type" in
        directory-index)
          if [ -n "$subdir" ] && [ "$subdir" != "null" ]; then
            curl -sfL --connect-timeout 10 --max-time 90 --retry 2 --retry-connrefused "$url" \
              | grep -oE "href=\"[^\"]*\"" | sed 's|href="||;s|"$||' \
              | grep -oE "$subdir" | sort -u \
              | while read -r d; do curl -sfL --connect-timeout 10 --max-time 90 --retry 2 --retry-connrefused "$url$d/" | grep -oE "$pattern" || true; done
          else
            curl -sfL --connect-timeout 10 --max-time 90 --retry 2 --retry-connrefused "$url" | grep -oE "$pattern" || true
          fi
          ;;
        git-tags)
          git ls-remote --tags "$url" | sed 's|.*refs/tags/||; s|\^{}$||'
          ;;
        rubygems)
          curl -sfL --connect-timeout 10 --max-time 90 --retry 2 --retry-connrefused "$url" | jq -r '.[].number'
          ;;
        *)
          echo "tvp-upstream: no adapter for source type '$type'" >&2
          return 1
          ;;
      esac
    }

    jq -c --argjson select "$select" \
      '.[] | select($select == null or (.pname as $p | $select | index($p)))' \
      "$manifest" | while read -r row; do
      pname=$(jq -r '.pname' <<< "$row")
      attr=$(jq -r '.attr' <<< "$row")
      type=$(jq -r '.upstream.type' <<< "$row")
      url=$(jq -r '.upstream.url' <<< "$row")
      subdir=$(jq -r '.upstream.subdirPattern // ""' <<< "$row")
      pattern=$(jq -r '.upstream.pattern // ""' <<< "$row")

      if ! fetch_raw "$type" "$url" "$subdir" "$pattern" | sort -u > "$work/raw"; then
        printf '%s: SKIPPED (%s)\n\n' "$pname" "$type"
        continue
      fi
      jq -R -s 'split("\n") | map(select(length > 0))' < "$work/raw" > "$work/raw.json"

      # normalise raw -> version (null drops it), then apply the include predicate
      nix eval --impure --json --apply "
        u: let
             raw  = builtins.fromJSON (builtins.readFile \"$work/raw.json\");
             norm = builtins.map (r: (u.normalise or (x: x)) r) raw;
             real = builtins.filter (v: v != null) norm;
           in builtins.filter (u.include or (_: true)) real
      " "$flake#packages.$system.$attr.tvp.upstream" 2>/dev/null \
        | jq -r '.[]' | sort -u > "$work/upstream" || true

      # A package always has at least one upstream release, so an empty listing is a
      # fetch failure, not a report. Reporting it as "N of 0 - nothing missing" turns a
      # rate-limited mirror into a clean bill of health.
      if ! [ -s "$work/upstream" ]; then
        printf '%s — FAILED: upstream listing came back empty\n' "$pname"
        printf '  source: %s %s\n' "$type" "$url"
        printf '  Retry, or use a mirror: ftp.gnu.org refuses connections after ~60 requests.\n\n'
        touch "$work/failed"
        continue
      fi

      jq -r '.versions[]' <<< "$row" | sort -u > "$work/have"
      jq -r '.upstream.unavailable // [] | .[].versions[]' <<< "$row" | sort -u > "$work/unavailable"
      comm -23 "$work/upstream" "$work/have" | comm -23 - "$work/unavailable" > "$work/missing"

      printf '%s — %s of %s upstream releases packaged\n' \
        "$pname" "$(wc -l < "$work/have")" "$(wc -l < "$work/upstream")"
      printf '  source: %s %s\n' "$type" "$url"
      if [ -s "$work/missing" ]; then
        printf '  not packaged (%s):\n' "$(wc -l < "$work/missing")"
        tr '\n' ' ' < "$work/missing" | fold -s -w 92 | sed 's/^/    /'
        echo
      else
        echo "  nothing missing"
      fi
      if [ -s "$work/unavailable" ]; then
        printf '  unavailable (%s) — exists upstream, cannot be packaged:\n' \
          "$(wc -l < "$work/unavailable")"
        jq -r '.upstream.unavailable // [] | .[]
               | (.versions | join(" ")), "why: " + .reason' <<< "$row" \
          | fold -s -w 88 | sed 's/^/    /'
      fi
      echo
    done

    if [ -e "$work/failed" ]; then
      echo "tvp-upstream: at least one upstream listing failed; the report above is incomplete" >&2
      exit 1
    fi
  '';
}

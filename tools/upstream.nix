# Reports which upstream releases exist that TVP has not packaged.
#
# Not hermetic: the answer depends on the network at query time, so this is a
# command and never a check.
{
  lib,
  ownedCLI,

  coreutils,
  curl,
  git,
  gnugrep,
  gnused,
  jq,
  python3,

  packages,
  tvpLib,
  phpCoverage ? { },
}:
let
  canonical = lib.filterAttrs (
    name: p:
    (p.pname or "") != ""
    && (p.version or "") != ""
    && name == tvpLib.versions.attrName p.pname p.version
    && p ? tvp
  ) packages;

  byPname = lib.groupBy (p: p.pname) (lib.attrValues canonical);

  # normalise/include are functions and cannot be serialised; they are applied
  # by evaluating the flake, so only their inputs travel through this file.
  describe =
    pname: ps:
    let
      php = phpCoverage.${pname} or null;
      # Mixed families discover standalone releases under their own upstream project.
      listed =
        if php != null && php.kind == "mixed" then
          let
            standalone = map (row: row.release) (
              builtins.filter (row: (row.kind or null) == "independent") php.rows
            );
          in
          builtins.filter (p: builtins.elem p.version standalone) ps
        else
          ps;
      ordered = lib.sort (a: b: builtins.compareVersions a.version b.version < 0) listed;
      latest = lib.last ordered;
    in
    {
      inherit pname php;
      attr = tvpLib.versions.attrName pname latest.version;
      versions = map (p: p.version) ordered;
      download = latest.tvp.source.url or null;
      upstream =
        if (latest.tvp.upstream or null) == null then
          null
        else
          removeAttrs latest.tvp.upstream [
            "normalise"
            "include"
          ];
    };

  manifest = builtins.toFile "tvp-upstream-manifest.json" (
    builtins.toJSON (lib.mapAttrsToList describe byPname)
  );
in
ownedCLI.shell {
  name = "tvp-upstream";
  runtimeInputs = [
    coreutils
    curl
    git
    gnugrep
    gnused
    jq
    python3
  ];
  text = ''
    manifest=${manifest}
    flake="."
    list=0
    json=0
    php_selector=""
    filters=()

    while [ $# -gt 0 ]; do
      case "$1" in
        --flake)
          if [ $# -lt 2 ] || [ -z "$2" ]; then
            echo 'tvp-upstream: --flake requires a reference' >&2
            exit 2
          fi
          flake="$2"; shift 2 ;;
        --list) list=1; shift ;;
        --json) json=1; shift ;;
        --php)
          if [ $# -lt 2 ] || ! [[ "$2" =~ ^[0-9]+([.][0-9]+){0,2}$ ]]; then
            echo 'tvp-upstream: --php requires a major, minor, or complete version' >&2
            exit 2
          fi
          php_selector="$2"; shift 2 ;;
        -h|--help)
          echo "usage: tvp-upstream [--flake REF] [--list] [--json] [--php VERSION] [PACKAGE...]"
          echo "Compare available upstream releases with packaged versions."
          echo "--list shows every family's configuration without contacting upstream."
          echo "--json reports discovery and release status for a frozen flake revision."
          echo "PHP extensions also report packaged combinations, packaging gaps, and source-backed hard limits."
          echo "--php selects an exact PHP version or a major/minor series."
          exit 0
          ;;
        -*) echo "tvp-upstream: unknown option '$1'" >&2; exit 2 ;;
        *) filters+=("$1"); shift ;;
      esac
    done

    system=""
    revision=""
    if [ "$json" = 1 ]; then
      metadata=$(nix flake metadata --json --no-write-lock-file "$flake")
      source=$(jq -er '.path | select(type == "string" and startswith("/nix/store/"))' <<< "$metadata")
      revision=$(jq -r '
        .revision | if type == "string" and test("^[0-9a-f]{40}$") then . else "" end
      ' <<< "$metadata")
      flake="path:$source"
      system=$(nix eval --raw --impure --expr 'builtins.currentSystem')
      manifest=$(nix eval --raw --offline --no-write-lock-file --option allow-import-from-derivation false \
        "$flake#legacyPackages.$system.upstreamManifest")
    fi

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

    php_coverage() {
      if [ "$(jq -r '.php != null' <<< "$row")" = true ]; then
        local php_args=()
        if [ -n "$php_selector" ]; then php_args+=("$php_selector"); fi
        jq -c '.php' <<< "$row" | \
          ${python3}/bin/python3 ${./upstream/php-coverage.py} - "''${php_args[@]}"
      elif [ -n "$php_selector" ]; then
        echo "tvp-upstream: --php requires a PHP extension family ($pname)" >&2
        exit 2
      fi
    }

    work=$(mktemp -d)
    trap 'rm -rf "$work"' EXIT

    if [ "$json" = 1 ]; then
      : > "$work/families.jsonl"
    fi

    record_family() {
      jq -c --arg status "$1" --arg error "''${2:-}" \
        --slurpfile listing "$work/listing.json" --slurpfile head "$work/head.json" '
        {row: ., status: $status, error: $error, listing: $listing[0], head: $head[0]}
      ' <<< "$row" >> "$work/families.jsonl"
    }

    ${builtins.readFile ./upstream/git-head.sh}

    grep_matches() {
      grep "$@" || [ "$?" = 1 ]
    }

    fetch_raw() {
      local type=$1 url=$2 subdir=$3 pattern=$4 selector=$5
      case "$type" in
        directory-index)
          if ! curl -sfL --connect-timeout 10 --max-time 90 --retry 2 --retry-connrefused -- "$url" > "$work/index"; then
            return 1
          fi
          if [ -n "$subdir" ] && [ "$subdir" != "null" ]; then
            grep_matches -oE "href=\"[^\"]*\"" < "$work/index" | sed 's|href="||;s|"$||' \
              | grep_matches -oE -- "$subdir" | sort -u \
              | while read -r d; do
                curl -sfL --connect-timeout 10 --max-time 90 --retry 2 --retry-connrefused -- "$url$d/" \
                  | grep_matches -oE -- "$pattern" || return 1
              done
          else
            grep_matches -oE -- "$pattern" < "$work/index"
          fi
          ;;
        git-tags)
          GIT_TERMINAL_PROMPT=0 timeout --signal=TERM --kill-after=5 45 \
            git -c credential.helper= -c core.askPass= ls-remote --tags -- "$url" \
              | sed 's|.*refs/tags/||; s|\^{}$||'
          ;;
        json-index)
          curl -sfL --connect-timeout 10 --max-time 90 --retry 2 --retry-connrefused "$url" \
            | jq -er "($selector) | if type == \"string\" and length > 0 then . else error(\"expected release string\") end"
          ;;
        android-repository)
          curl -sfL --connect-timeout 10 --max-time 90 --retry 2 --retry-connrefused "$url" \
            | ${python3}/bin/python3 ${./upstream/android-repository.py} "$row"
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

    jq -c --argjson select "$select" --arg php "$php_selector" \
      '.[] | select(($select == null and ($php == "" or .php != null)) or
                    (.pname as $p | $select != null and ($select | index($p))))' \
      "$manifest" | while read -r row; do
      pname=$(jq -r '.pname' <<< "$row")
      attr=$(jq -r '.attr' <<< "$row")
      type=$(jq -r '.upstream.type' <<< "$row")
      if [ "$json" = 1 ]; then
        : > "$work/listing.json"
        : > "$work/head.json"
        if [ "$type" = null ]; then
          record_family unconfigured
          continue
        elif [ "$list" = 1 ]; then
          record_family not-queried
          continue
        fi
      fi
      if [ "$list" = 1 ]; then
        scope_label=""
        if [ "$(jq -r '.php.kind' <<< "$row")" = mixed ]; then scope_label=" standalone"; fi
        printf '%s — %s%s packaged; discovery: %s\n' "$pname" \
          "$(jq '.versions | length' <<< "$row")" \
          "$scope_label" \
          "$(jq -r '.upstream.type // "not configured"' <<< "$row")"
        php_coverage
        continue
      fi
      if [ "$type" = null ]; then
        printf '%s — release discovery not configured\n' "$pname"
        printf '  packaged: %s\n' "$(jq -r '.versions | join(" ")' <<< "$row")"
        printf '  download: %s\n' "$(jq -r '.download // "not described"' <<< "$row")"
        printf '  missing versions: unknown\n\n'
        php_coverage
        continue
      fi
      url=$(jq -r '.upstream.url' <<< "$row")
      subdir=$(jq -r '.upstream.subdirPattern // ""' <<< "$row")
      pattern=$(jq -r '.upstream.pattern // ""' <<< "$row")
      selector=$(jq -r '.upstream.selector // ""' <<< "$row")
      scope=$(jq -r '.upstream.scope // ""' <<< "$row")

      # Untagged projects have snapshots, not numbered releases. Compare only
      # the declared branch head; do not imply that its history was enumerated.
      if [ "$type" = git-head ]; then
        if ! upstream_git_head "$row" > "$work/head.json"; then
          if [ "$json" = 1 ]; then
            : > "$work/head.json"
            record_family error "commit head comparison failed"
          else
            printf '%s — FAILED: commit head comparison failed\n\n' "$pname"
          fi
          touch "$work/failed"
          continue
        fi
        if [ "$json" = 1 ]; then
          record_family ok
          continue
        fi
        printf '%s — upstream branch head comparison (history not enumerated)\n' "$pname"
        printf '  source: %s %s\n' "$type" "$url"
        if [ -n "$scope" ]; then printf '  scope: %s\n' "$scope"; fi
        jq -r '"  ref: " + .ref,
               "  remote head: " + .remoteHead,
               (.packagedRevisions[] | "  packaged " + .version + ": " + .revision),
               "  head packaged: " + (.headPackaged | tostring),
               "  missing revision: " + (.missingRevision // "none")' "$work/head.json"
        echo
        continue
      fi

      if ! fetch_raw "$type" "$url" "$subdir" "$pattern" "$selector" | sort -u > "$work/raw"; then
        if [ "$json" = 1 ]; then
          record_family error "could not read upstream listing ($type)"
        else
          printf '%s — FAILED: could not read upstream listing (%s)\n\n' "$pname" "$type"
          php_coverage
        fi
        touch "$work/failed"
        continue
      fi
      jq -R -s 'split("\n") | map(select(length > 0))' < "$work/raw" > "$work/raw.json"

      # normalise raw -> version (null drops it), then apply the include predicate
      if [ -z "$system" ]; then
        system=$(nix eval --raw --impure --expr 'builtins.currentSystem') || exit 1
      fi
      if ! nix eval --impure --json --no-write-lock-file --option allow-import-from-derivation false --apply "
        u: let
             raw  = builtins.fromJSON (builtins.readFile \"$work/raw.json\");
             norm = builtins.map (r: (u.normalise or (x: x)) r) raw;
             real = builtins.filter (v: v != null) norm;
             include = u.include or (_: true);
           in {
             included = builtins.filter include real;
             excluded = if $json == 1 then builtins.filter (v: !(include v)) real else [];
           }
      " "$flake#packages.$system.$attr.tvp.upstream" > "$work/listing.json" 2>/dev/null; then
        : > "$work/listing.json"
        if [ "$json" = 1 ]; then
          record_family error "could not evaluate the upstream release rules"
          touch "$work/failed"
          continue
        fi
      fi
      jq -r '.included[]' < "$work/listing.json" | sort -u > "$work/upstream"

      # A package always has at least one upstream release, so an empty listing is a
      # fetch failure, not a report. Reporting it as "N of 0 - nothing missing" turns a
      # rate-limited mirror into a clean bill of health.
      if ! [ -s "$work/upstream" ]; then
        if [ "$json" = 1 ]; then
          record_family error "upstream listing came back empty"
          touch "$work/failed"
          continue
        fi
        printf '%s — FAILED: upstream listing came back empty\n' "$pname"
        printf '  source: %s %s\n' "$type" "$url"
        printf '  Retry, or use a mirror: ftp.gnu.org refuses connections after ~60 requests.\n\n'
        php_coverage
        touch "$work/failed"
        continue
      fi
      if [ "$json" = 1 ]; then
        record_family ok
        continue
      fi

      jq -r '.versions[]' <<< "$row" | sort -u > "$work/have"
      jq -r '.upstream.unavailable // [] | .[].versions[]' <<< "$row" | sort -u > "$work/unavailable"
      comm -12 "$work/upstream" "$work/have" > "$work/packaged-upstream"
      comm -23 "$work/have" "$work/upstream" > "$work/unlisted-packaged"
      comm -23 "$work/upstream" "$work/have" | comm -23 - "$work/unavailable" > "$work/missing"

      printf '%s — %s of %s upstream releases packaged\n' \
        "$pname" "$(wc -l < "$work/packaged-upstream")" "$(wc -l < "$work/upstream")"
      printf '  source: %s %s\n' "$type" "$url"
      if [ -n "$scope" ]; then printf '  scope: %s\n' "$scope"; fi
      if [ -s "$work/missing" ]; then
        printf '  not packaged (%s):\n' "$(wc -l < "$work/missing")"
        tr '\n' ' ' < "$work/missing" | fold -s -w 92 | sed 's/^/    /'
        echo
        if [ "$(jq -r '.php != null' <<< "$row")" = true ]; then
          echo '  PHP compatibility of unregistered releases: unknown (requirements not recorded)'
        fi
      else
        echo "  nothing missing"
      fi
      if [ -s "$work/unlisted-packaged" ]; then
        printf '  packaged outside this listing (%s):\n' "$(wc -l < "$work/unlisted-packaged")"
        tr '\n' ' ' < "$work/unlisted-packaged" | fold -s -w 92 | sed 's/^/    /'
        echo
      fi
      if [ -s "$work/unavailable" ]; then
        printf '  unavailable (%s) — exists upstream, cannot be packaged:\n' \
          "$(wc -l < "$work/unavailable")"
        jq -r '.upstream.unavailable // [] | .[]
               | (.versions | join(" ")), "why: " + .reason' <<< "$row" \
          | fold -s -w 88 | sed 's/^/    /'
      fi
      php_coverage
      echo
    done

    if [ "$json" = 1 ]; then
      ${python3}/bin/python3 ${./upstream/report.py} "$revision" "$php_selector" < "$work/families.jsonl"
    fi
    if [ -e "$work/failed" ]; then
      echo "tvp-upstream: at least one upstream listing failed; the report above is incomplete" >&2
      exit 1
    fi
  '';
}
// {
  inherit manifest;
}

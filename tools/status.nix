# Reports what TVP claims about each package version, and every gap it declares.
#
# Everything but the build surface is hermetic — a property of the tree, so it
# could be a check. The build surface reads a realised store instead.
{
  lib,
  ownedCLI,

  coreutils,
  gnused,
  gnugrep,
  jq,

  packages,
  bases,
  tvpLib,
}:
let
  canonical = lib.filterAttrs (
    name: p:
    (p.pname or "") != ""
    && (p.version or "") != ""
    && name == tvpLib.versions.attrName p.pname p.version
  ) packages;

  # A TVP package carries `passthru.tvp`; a nixpkgs one does not.
  foreignDeps = p: lib.attrNames (lib.filterAttrs (_: d: !(d ? tvp)) (p.tvp.deps or { }));

  rows = lib.mapAttrsToList (
    name: p:
    let
      level = p.tvp.status.level or "ok";
      # A broken version has no realisable paths, and forcing them throws.
      measurable = level != "broken";
    in
    {
      attr = name;
      inherit (p) pname version;
      inherit level;
      reason = p.tvp.status.reason or "";
      needs = p.tvp.status.needs or "";
      blocked = lib.mapAttrsToList (kind: want: "${kind} ${want}") (p.tvp.status.blocked or { });

      base = p.tvp.base or null;
      infra = p.tvp.infra or [ ];
      foreign = foreignDeps p;
      blob = p.tvp.blob or null;

      # Context discarded, or reading this report would build the repository.
      drv = if measurable then builtins.unsafeDiscardStringContext p.drvPath else null;
      out = if measurable then builtins.unsafeDiscardStringContext p.outPath else null;
    }
  ) canonical;

  baseRows = lib.mapAttrsToList (name: b: {
    inherit name;
    builtBy = b.builtBy;
    drv =
      if (b.stdenv or null) == null then null else builtins.unsafeDiscardStringContext b.stdenv.drvPath;
  }) (lib.filterAttrs (name: b: b.name == name) bases);

  manifest = builtins.toFile "tvp-status.json" (
    builtins.toJSON {
      versions = rows;
      bases = baseRows;
    }
  );
in
ownedCLI.shell {
  name = "tvp-status";
  runtimeInputs = [
    coreutils
    gnused
    gnugrep
    jq
  ];
  text = ''
    manifest=${manifest}

    work=$(mktemp -d)
    trap 'rm -rf "$work"' EXIT

    # --stdin rather than arguments: a large enough catalogue exceeds argv and
    # gets split into batches, each of which re-walks the shared substrate.
    closure() {
      nix-store -qR --include-outputs --stdin < "$1" 2> /dev/null | grep -v '\.drv$' | sort -u
    }

    # A directory is a package output; the rest are tarballs, patches and setup
    # hooks. Counted per output, as provenance counts them, so the two reports
    # can be read against each other.
    names() {
      while read -r p; do
        if [ -d "$p" ]; then printf '%s\n' "''${p##*/}"; fi
      done \
        | sed -E 's/^[a-z0-9]{32}-//' \
        | sort -u
    }

    surface=null
    if command -v nix-store > /dev/null 2>&1; then
      jq -r '.versions[] | select(.drv != null) | .drv' "$manifest" | sort -u > "$work/drvs"
      jq -r '.versions[] | select(.out != null) | .out' "$manifest" | sort -u > "$work/outs"
      jq -r '.bases[] | select(.drv != null) | .drv' "$manifest" | sort -u > "$work/base-drvs"

      closure "$work/drvs" > "$work/reached" || true
      closure "$work/base-drvs" > "$work/base-reached" || true

      if [ -s "$work/reached" ]; then
        comm -23 "$work/reached" "$work/outs" | names > "$work/all"
        comm -23 "$work/base-reached" "$work/outs" | names > "$work/floor"
        comm -13 "$work/floor" "$work/all" > "$work/beyond"

        surface=$(jq -Rn \
          --rawfile all "$work/all" \
          --rawfile floor "$work/floor" \
          --rawfile beyond "$work/beyond" '
          def count: split("\n") | map(select(length > 0)) | length;
          {
            total: ($all | count),
            base: ($floor | count),
            beyond: ($beyond | count),
          }')
      fi
    fi

    if [ "''${1:-}" = "--json" ]; then
      jq --argjson surface "$surface" '. + { buildSurface: $surface }' "$manifest"
      exit 0
    fi

    total=$(jq '.versions | length' "$manifest")
    printf '%s canonical versions\n\n' "$total"

    for level in ok degraded broken; do
      n=$(jq --arg l "$level" '[.versions[] | select(.level == $l)] | length' "$manifest")
      printf '  %-9s %s\n' "$level" "$n"
    done
    echo

    # Only the interesting rows in full: "ok" is the case with nothing to say.
    jq -r '
      [.versions[] | select(.level != "ok")]
      | group_by(.level)[]
      | "\(.[0].level | ascii_upcase) (\(length))",
        (group_by(.reason)[]
         | "  \(.[0].pname) \(map(.version) | join(" "))",
           "    why:   \(.[0].reason)",
           "    needs: \(.[0].needs)",
           "")
    ' "$manifest"

    # What owning a thing would unlock, counted upward from versions. The
    # mirror of provenance, which counts downward from closures.
    jq -r '
      [.versions[] | select(.blocked | length > 0) | .blocked[] as $b | {b: $b, v: "\(.pname) \(.version)"}]
      | if length == 0 then empty else
          "BLOCKED ON",
          "",
          (group_by(.b)[]
           | "  \(.[0].b) — \(length) versions",
             "    \(map(.v) | join(", "))",
             "")
        end
    ' "$manifest"

    echo "DECLARED GAPS"
    echo

    jq -r '
      def plural(n; s): if n == 1 then s else s + "s" end;

      ([.versions[] | select(.foreign | length > 0)] | length) as $nf
      | "  foreign dependencies — named in `deps`, but not TVP packages",
        (if $nf == 0 then "    none" else
          ([.versions[]
            | . as $v
            | .foreign[]
            | { dep: ., pname: $v.pname, version: $v.version }]
           | group_by(.dep)[]
           | "    \(.[0].dep)  (\(length) \(plural(length; "version"))): "
             + (group_by(.pname) | map("\(.[0].pname) \(map(.version) | min) … \(map(.version) | max)") | join(", ")))
        end),
        "",

        "  binary blobs — installed, not built from source",
        ([.versions[] | select(.blob != null)] as $b
         | if ($b | length) == 0 then "    none" else
             ($b | group_by(.pname)[]
              | "    \(.[0].pname) \(map(.version) | join(" "))",
                "      why:   \(.[0].blob.reason)",
                "      needs: \(.[0].blob.needs)")
           end),
        "",

        "  not on a TVP base",
        ([.versions[] | select(.base == null)] as $n
         | if ($n | length) == 0 then "    none" else
             ($n | group_by(.pname)[] | "    \(.[0].pname) \(map(.version) | join(" "))")
           end),
        "",

        "  nixpkgs infrastructure — supplied to builders unnamed",
        ([.versions[] | { i: (.infra | join(" ")), pname }] | unique_by(.pname)
         | group_by(.i)[]
         | "    \(.[0].i)  (\(length) \(plural(length; "package"))): \(map(.pname) | join(" "))"),
        "",

        "  bases not built by TVP",
        ([.bases[] | select(.builtBy == null)] as $bb
         | if ($bb | length) == 0 then "    none" else
             "    \($bb | map(.name) | join(" "))  builtBy = null"
           end)
    ' "$manifest"

    echo

    # The totals only. Which ones, and what each is needed by, is provenance's
    # question rather than this one's.
    jq -rn --argjson surface "$surface" '
      "BUILD SURFACE — measured, not declared",
      "",
      (if $surface == null then "  not measured — needs a realised store" else
        "  \($surface.total) foreign outputs are reachable while building the catalogue",
        "    \($surface.base) brought by a base",
        "    \($surface.beyond) beyond every base"
       end)
    '
  '';
}

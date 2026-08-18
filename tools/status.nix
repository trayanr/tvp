# Reports what TVP claims about each package version, and every gap it declares.
#
# Hermetic, unlike provenance and upstream: the answer is a property of the
# tree, so this could be a check. It is a command because its job is to be read.
{
  lib,
  writeShellApplication,
  writeText,
  coreutils,
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

  rows = lib.mapAttrsToList (name: p: {
    attr = name;
    inherit (p) pname version;
    level = p.tvp.status.level or "ok";
    reason = p.tvp.status.reason or "";
    needs = p.tvp.status.needs or "";

    base = p.tvp.base or null;
    infra = p.tvp.infra or [ ];
    foreign = foreignDeps p;
    blob = p.tvp.blob or null;
  }) canonical;

  baseRows = lib.mapAttrsToList (name: b: {
    inherit name;
    builtBy = b.builtBy;
  }) (lib.filterAttrs (name: b: b.name == name) bases);

  manifest = writeText "tvp-status.json" (
    builtins.toJSON {
      versions = rows;
      bases = baseRows;
    }
  );
in
writeShellApplication {
  name = "tvp-status";
  runtimeInputs = [
    coreutils
    jq
  ];
  text = ''
    manifest=${manifest}

    if [ "''${1:-}" = "--json" ]; then
      cat "$manifest"
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
  '';
}

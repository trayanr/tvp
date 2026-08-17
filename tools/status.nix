# Reports what TVP claims about each package version.
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
  tvpLib,
}:
let
  canonical = lib.filterAttrs (
    name: p:
    (p.pname or "") != ""
    && (p.version or "") != ""
    && name == tvpLib.versions.attrName p.pname p.version
  ) packages;

  rows = lib.mapAttrsToList (name: p: {
    attr = name;
    inherit (p) pname version;
    level = p.tvp.status.level or "ok";
    reason = p.tvp.status.reason or "";
    needs = p.tvp.status.needs or "";
  }) canonical;

  manifest = writeText "tvp-status.json" (builtins.toJSON rows);
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

    total=$(jq 'length' "$manifest")
    printf '%s canonical versions\n\n' "$total"

    for level in ok degraded broken; do
      n=$(jq --arg l "$level" '[.[] | select(.level == $l)] | length' "$manifest")
      printf '  %-9s %s\n' "$level" "$n"
    done
    echo

    # Only the interesting rows in full: "ok" is the case with nothing to say.
    jq -r '
      [.[] | select(.level != "ok")]
      | group_by(.level)[]
      | "\(.[0].level | ascii_upcase) (\(length))",
        (group_by(.reason)[]
         | "  \(.[0].pname) \(map(.version) | join(" "))",
           "    why:   \(.[0].reason)",
           "    needs: \(.[0].needs)",
           "")
    ' "$manifest"
  '';
}

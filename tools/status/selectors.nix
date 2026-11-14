# Status observes declared aliases. The real latest gate additionally validates
# producer/suite/batch identities in lib/latest-tests.nix and remains unchanged.
{
  lib,
  canonical,
  packages,
}:
let
  grouped = lib.groupBy (name: canonical.${name}.pname) (builtins.attrNames canonical);
  eligible = lib.mapAttrs (
    _: names: builtins.filter (name: (canonical.${name}.tvp.status.level or "ok") != "broken") names
  ) grouped;
  fail = family: throw "TVP status: inconsistent declared latest selector for ${family}";
in
{
  measurement = "declared-selectors";
  families = lib.mapAttrs (
    family: names:
    let
      selected = packages.${family};
      selector = selected.__tvpSelection or { };
      job = selector.canonical or "";
      package = canonical.${job};
    in
    if !(packages ? ${family}) || !(builtins.elem job names) then
      fail family
    else if
      (selector.namespace or null) != "packages"
      || (selector.selector or null) != family
      || (selector.pname or null) != family
      || !(builtins.elem (selector.kind or null) [
        "latest"
        "override"
      ])
      || selected.pname != family
      || selected.version != package.version
      || (selector.version or null) != package.version
      || !(builtins.all (
        name: builtins.compareVersions canonical.${name}.version package.version <= 0
      ) names)
    then
      fail family
    else
      {
        inherit job;
        inherit (package) version;
      }
  ) (lib.filterAttrs (_: names: names != [ ]) eligible);
  skipped = lib.mapAttrsToList (family: _: {
    inherit family;
    reason = "All declared releases are broken; no usable family alias or batch is required.";
  }) (lib.filterAttrs (_: names: names == [ ]) eligible);
}

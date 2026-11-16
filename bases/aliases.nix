# Moving major selectors use table versions, never compiler/provider evaluation.
# A new 4.x entry advances gcc_4 while existing exact selectors remain available.
{ pname, versions }:
let
  latest = builtins.foldl' (
    selected: version:
    let
      parsed = builtins.match "([0-9]+).*" version;
      major =
        if parsed == null then throw "TVP bases: invalid version '${version}'" else builtins.head parsed;
    in
    if !(selected ? ${major}) || builtins.compareVersions version selected.${major} > 0 then
      selected // { ${major} = version; }
    else
      selected
  ) { } (builtins.attrNames versions);
in
builtins.listToAttrs (
  map (major: {
    name = "${pname}_${major}";
    value = versions.${latest.${major}};
  }) (builtins.attrNames latest)
)

{
  lib,
  tvpLib,
  canonical,
  variantPackages,
  registry,
}:
let
  entryKind =
    name: p:
    let
      pname = p.pname or "";
      version = p.version or "";
    in
    if (p.tvp.variant or null) != null then
      "variant"
    else if pname != "" && version != "" && name == tvpLib.versions.attrName pname version then
      "canonical"
    else
      "alias";
  entry = name: p: {
    package = name;
    kind = entryKind name p;
    source = tvpLib.provenance.sourceKind p;
    sourceUrl = p.tvp.source.url or null;
    upstreamUrl = p.tvp.upstream.url or null;
    recipe = {
      builder = p.tvp.builder or null;
      definition = p.tvp.definition or null;
    };
    blob = p.tvp.blob or null;
    base = p.tvp.base or null;
    status = p.tvp.status.level or "ok";
  };
in
{
  inherit registry;
  declarations = lib.mapAttrsToList entry (canonical // variantPackages);
  runtimeRoots = lib.mapAttrs (_: p: builtins.unsafeDiscardStringContext p.outPath) (
    lib.filterAttrs (
      name: p: (p.tvp.status.level or "ok") != "broken" && entryKind name p == "canonical"
    ) canonical
  );
}

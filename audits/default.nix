{ pkgs, tvp }:
let
  inherit (pkgs) lib;
  packages = lib.filterAttrs (_: p: (p.tvp.status.level or "ok") != "broken") tvp.canonical;
  compositions = lib.mapAttrs' (name: p: lib.nameValuePair "android:${name}" p) tvp.android.profiles;
  roots = packages // compositions;
  registry = tvp.lib.provenance.registry {
    inherit (tvp) canonical variants bases;
    compositions = tvp.android.profiles;
  };
  manifest = {
    roots = lib.attrNames roots;
    legacy = builtins.fromJSON (builtins.readFile ./runtime-baseline.json);
    registeredPaths = lib.unique (map (row: row.path) registry);
  };
  invalidProvenance = lib.filterAttrs (
    _: p:
    let
      provenance = p.meta.sourceProvenance or [ ];
      binary = builtins.any (kind: builtins.elem kind provenance) [
        lib.sourceTypes.binaryNativeCode
        lib.sourceTypes.binaryBytecode
      ];
    in
    binary && !(p.tvp ? blob)
  ) packages;
in
{
  audit-contracts = import ./tests { inherit tvp; };
  provenance-declarations =
    if invalidProvenance != { } then
      throw "TVP: precompiled provenance without a declared blob boundary: ${lib.concatStringsSep ", " (lib.attrNames invalidProvenance)}"
    else if
      builtins.hasContext (builtins.toJSON tvp.graph) || builtins.hasContext (builtins.toJSON registry)
    then
      throw "TVP: graph/provenance manifests must not force package builds."
    else
      pkgs.writeText "tvp-provenance-declarations.json" (
        builtins.toJSON {
          sourceKinds = lib.mapAttrs (_: p: tvp.lib.provenance.sourceKind p) packages;
          sourceKindsAreDeclarations = true;
        }
      );
  runtime-policy = pkgs.writeText "tvp-runtime-audit-policy.json" (builtins.toJSON manifest);
  package-runtime-ownership = tvp.bases.gcc13-owned-v2.stdenv.mkDerivation {
    name = "tvp-catalogue-runtime-ownership";
    __structuredAttrs = true;
    exportReferencesGraph.runtime = lib.attrValues roots;
    runtimeRoots = lib.mapAttrs (_: p: builtins.unsafeDiscardStringContext p.outPath) roots;
    inherit (manifest) registeredPaths;
    nativeBuildInputs = [ tvp.packages.python_3_12_16 ];
    dontUnpack = true;
    dontConfigure = true;
    dontBuild = true;
    dontFixup = true;
    installPhase = ''python3 ${./runtime.py} ${./runtime-baseline.json}'';
  };
}

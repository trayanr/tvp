{
  pkgs,
  tvp,
  registry,
}:
let
  inherit (pkgs) lib;
  packages = lib.filterAttrs (_: p: (p.tvp.status.level or "ok") != "broken") tvp.canonical;
  compositions = lib.mapAttrs' (name: p: lib.nameValuePair "android:${name}" p) tvp.android.profiles;
  roots = packages // compositions;
  manifest = {
    roots = lib.attrNames roots;
    legacy = builtins.fromJSON (builtins.readFile ./runtime-baseline.json);
    registeredPaths = lib.unique (map (row: row.path) registry);
  };
  # The family alias is chosen from release-table metadata by mkAliases. Do not
  # sort job names: suffixes and lettered releases are catalogue semantics.
  families = lib.unique (map (p: p.pname) (lib.attrValues packages));
  latestPackages = lib.listToAttrs (
    map (
      family:
      let
        selected = tvp.packages.${family};
        name = selected.__tvpSelection.canonical;
      in
      assert selected.pname == family;
      assert selected.drvPath == packages.${name}.drvPath;
      lib.nameValuePair name packages.${name}
    ) families
  );
  latestBaseline = lib.filterAttrs (name: _: builtins.hasAttr name latestPackages) manifest.legacy;
  latestManifest = manifest // {
    roots = lib.attrNames latestPackages;
    legacy = latestBaseline;
  };
  runtimeOwnership =
    name: selectedRoots: baselineFile:
    tvp.bases.default.stdenv.mkDerivation {
      inherit name;
      __structuredAttrs = true;
      exportReferencesGraph.runtime = lib.attrValues selectedRoots;
      runtimeRoots = lib.mapAttrs (_: p: builtins.unsafeDiscardStringContext p.outPath) selectedRoots;
      inherit (manifest) registeredPaths;
      nativeBuildInputs = [ tvp.packages.python_3 ];
      dontUnpack = true;
      dontConfigure = true;
      dontBuild = true;
      dontFixup = true;
      installPhase = ''python3 ${./runtime.py} ${baselineFile}'';
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
  audit-contracts = import ./tests { inherit tvp lib; };
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
  package-runtime-ownership =
    runtimeOwnership "tvp-catalogue-runtime-ownership" roots
      ./runtime-baseline.json;
  runtime-policy-latest = pkgs.writeText "tvp-latest-runtime-audit-policy.json" (
    builtins.toJSON latestManifest
  );
  package-runtime-ownership-latest = runtimeOwnership "tvp-latest-runtime-ownership" latestPackages (
    builtins.toFile "tvp-latest-runtime-baseline.json" (builtins.toJSON latestBaseline)
  );
}

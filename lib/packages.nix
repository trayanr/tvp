{ lib, versions }:
{
  # `callPackage` fills in the substrate; everything in `deps` is passed
  # explicitly and is therefore also the seam `.override` needs.
  mkVersions =
    {
      callPackage,
      pname,
      versionTable,
      extraArgs ? { },
    }:
    lib.mapAttrs' (
      version: entry:
      lib.nameValuePair (versions.attrName pname version) (
        callPackage entry.builder (
          {
            inherit version;
            inherit (entry) sha256;
          }
          // entry.deps
          // extraArgs
        )
      )
    ) versionTable;

  # `//` would resolve a duplicate silently in favour of the last set. Names
  # only: forcing a package here recurses, since bundler pins a TVP Ruby.
  merge =
    sets:
    let
      owners = lib.foldl' (
        acc: source:
        lib.foldl' (a: attr: a // { ${attr} = (a.${attr} or [ ]) ++ [ source ]; }) acc (
          lib.attrNames sets.${source}
        )
      ) { } (lib.attrNames sets);

      clashes = lib.filterAttrs (_: srcs: lib.length srcs > 1) owners;
    in
    if clashes == { } then
      lib.foldl' (a: b: a // b) { } (lib.attrValues sets)
    else
      throw "TVP: package names defined more than once: ${
        lib.concatStringsSep ", " (
          lib.mapAttrsToList (attr: srcs: "${attr} (${lib.concatStringsSep " + " srcs})") clashes
        )
      }";

  checkAliases =
    { canonical, aliases }:
    let
      shadowed = lib.intersectLists (lib.attrNames canonical) (lib.attrNames aliases);
    in
    if shadowed == [ ] then
      aliases
    else
      throw "TVP: aliases shadow canonical names: ${lib.concatStringsSep ", " shadowed}";
}

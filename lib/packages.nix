{ lib, versions }:
{
  # `callPackage` fills in the substrate; everything in `deps` is passed
  # explicitly and is therefore also the seam `.override` needs.
  # `packageMeta` describes the package rather than a version — one upstream
  # index serves all nine Rubies. It is written once in the package's
  # default.nix and copied onto each version's passthru, because the package set
  # is flat and versions are the only things with a name in it.
  mkVersions =
    {
      callPackage,
      pname,
      versionTable,
      extraArgs ? { },
      packageMeta ? { },
    }:
    lib.mapAttrs' (
      version: entry:
      lib.nameValuePair (versions.attrName pname version) (
        let
          pkg = callPackage entry.builder (
            {
              inherit version;
              inherit (entry) sha256;
            }
            // entry.deps
            // extraArgs
          );
        in
        if packageMeta == { } then
          pkg
        else
          pkg.overrideAttrs (old: {
            passthru = old.passthru // {
              tvp = (old.passthru.tvp or { }) // packageMeta;
            };
          })
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

{ lib, versions }:
rec {
  # What TVP claims about a version, as a fact rather than a comment.
  #
  #   ok        built the way upstream builds it
  #   degraded  builds and passes its tests, but a documented capability is off
  #   broken    does not build
  #
  # Anything other than `ok` must say what is wrong and what would fix it, so a
  # status can never decay into an unexplained label nobody dares remove.
  # Evaluation-only: it reaches `meta` and `passthru`, both of which
  # `mkDerivation` strips before hashing.
  statusLevels = [
    "ok"
    "degraded"
    "broken"
  ];

  checkStatus =
    attr: status:
    if !(lib.elem status.level statusLevels) then
      throw "TVP: ${attr} has status level '${status.level}'; expected one of ${lib.concatStringsSep ", " statusLevels}"
    else if status.level != "ok" && !(status ? reason && status ? needs) then
      throw "TVP: ${attr} is '${status.level}' and must declare both `reason` and `needs`"
    else
      status;

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
      let
        attr = versions.attrName pname version;
        status = checkStatus attr (entry.status or { level = "ok"; });

        pkg = callPackage entry.builder (
          {
            inherit version;
            inherit (entry) sha256;
          }
          // entry.deps
          // extraArgs
        );
      in
      lib.nameValuePair attr (
        pkg.overrideAttrs (old: {
          passthru = old.passthru // {
            tvp = (old.passthru.tvp or { }) // packageMeta // { inherit status; };
          };

          # Nix's own machinery participates: a broken package refuses to build
          # rather than only being labelled.
          meta = (old.meta or { }) // lib.optionalAttrs (status.level == "broken") { broken = true; };
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

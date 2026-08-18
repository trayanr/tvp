{ lib, versions }:
rec {
  # What TVP claims about a version, as a fact rather than a comment.
  #
  #   ok        built the way upstream builds it
  #   degraded  builds, but a documented capability is off or a known defect bites
  #   broken    does not build here
  #
  # Anything other than `ok` must say what is wrong and what would fix it, so a
  # status can never decay into an unexplained label nobody dares remove.
  # Evaluation-only: it reaches `passthru`, which `mkDerivation` strips before
  # hashing.
  #
  # Deliberately not `meta.broken`. That makes Nix refuse to *evaluate* the
  # attribute, which breaks `nix flake check` and hides the version from the
  # catalogue — the opposite of what a preservation project wants. A broken
  # version stays addressable and stays listed; the status is the record.
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
    else if (status.knownTestFailures or [ ]) != [ ] && status.level == "ok" then
      throw "TVP: ${attr} declares knownTestFailures but claims level 'ok'"
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
      # Required rather than defaulted: a package that silently landed on the
      # wrong base would be invisible, whereas a missing argument fails to
      # evaluate. Same reason `mkTests` is mandatory in builders.
      defaultBase,
      extraArgs ? { },
      packageMeta ? { },
    }:
    lib.mapAttrs' (
      version: entry:
      let
        attr = versions.attrName pname version;
        status = checkStatus attr (entry.status or { level = "ok"; });
        base = entry.base or defaultBase;

        pkg = callPackage entry.builder (
          {
            inherit version;
            inherit (entry) sha256;
          }
          # The whole base mechanism. Builders already take `stdenv` and already
          # call `stdenv.mkDerivation`, so naming it here is the only edit a base
          # ever needs — no builder mentions bases at all.
          #
          # A null base means the builder does not take a stdenv because it
          # delegates to a nixpkgs helper, and is therefore not on a TVP base at
          # all. That has to be declared rather than inferred: it is an M9
          # worklist entry, and `passthru.tvp.base` reports it as null.
          // lib.optionalAttrs (base != null) { inherit (base) stdenv; }
          // entry.deps
          // extraArgs
        );
      in
      lib.nameValuePair attr (
        pkg.overrideAttrs (old: {
          passthru = old.passthru // {
            tvp =
              (old.passthru.tvp or { })
              // packageMeta
              // {
                inherit status;
                # The name, not the record: passthru is read by tooling, and a
                # whole stdenv in it makes `nix eval` unusable.
                base = if base == null then null else base.name;
              };

            # A test a release is known to fail is dropped from the suite, never
            # silently, and only where the status says which and why. Keeping it
            # would make CI red forever and train everyone to ignore it; deleting
            # the test would hide the defect from every other version.
            tests = removeAttrs (old.passthru.tests or { }) (status.knownTestFailures or [ ]);
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

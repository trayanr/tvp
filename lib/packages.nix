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

  # A definition is named for the version where it first appears, and that name
  # has to reach the version table for `definition-names` to check it. Tagging
  # here rather than at each use is what makes it unforgeable: a definition that
  # never went through mkDefs has no name and fails to evaluate.
  mkDefs = lib.mapAttrs (name: def: def // { inherit name; });

  checkDeps =
    attr: deps:
    let
      bad = lib.attrNames (lib.filterAttrs (_: v: !(lib.isDerivation v)) deps);
    in
    if bad == [ ] then
      deps
    else
      throw "TVP: ${attr} has non-derivation values in `deps`: ${lib.concatStringsSep ", " bad}. Build options belong in `opts`.";

  # Releases grouped under the definition they use. A list, not an attrset, so
  # blocks stay in release order and a definition may appear in more than one —
  # openssl 0.9 returns to its first recipe after the hardened run.
  #
  # A release is its hash, or an attrset where there is more than a hash to
  # state. Nix rejects a duplicate within one block; this catches one across
  # blocks, which it cannot see.
  #
  # A status belongs to the block when the recipe causes it — every ruby 4.0 is
  # degraded for the same reason — and to the release when the release does, as
  # openssl 3.0.4 is alone in its 64. Both at once is a contradiction, not a
  # merge.
  mkTable =
    blocks:
    let
      entries = lib.concatMap (
        block:
        lib.mapAttrsToList (
          version: raw:
          let
            release = if lib.isString raw then { sha256 = raw; } else raw;
          in
          if !(block ? def) then
            throw "TVP: the block holding ${version} names no definition."
          else if block ? status && release ? status then
            throw "TVP: ${version} declares a status and so does its block. One of them is wrong."
          else
            lib.nameValuePair version (
              {
                inherit (block) def;
              }
              // lib.optionalAttrs (block ? status) { inherit (block) status; }
              // release
            )
        ) block.releases
      ) blocks;

      names = map (e: e.name) entries;
      dupes = lib.unique (lib.filter (n: lib.count (m: m == n) names > 1) names);
    in
    if dupes == [ ] then
      lib.listToAttrs entries
    else
      throw "TVP: versions in more than one block: ${lib.concatStringsSep ", " dupes}";

  # A version names a definition and adds only what varies per release. Naming
  # one forbids overriding it: a version whose recipe differs forks a definition.
  entryFields = [
    "def"
    "sha256"
    "status"
  ];

  checkEntry =
    attr: entry:
    let
      extra = lib.subtractLists entryFields (lib.attrNames entry);
    in
    if !(entry ? def) || extra == [ ] then
      entry
    else
      throw "TVP: ${attr} sets ${lib.concatStringsSep ", " extra} alongside `def`. A version that differs forks its definition rather than overriding it.";

  # Source TVP changed, and why. A patch is version data: it belongs to the
  # definition that needs it and never forks a builder, which only holds
  # procedure. The builder receives bare paths; the reasons reach the catalogue.
  checkPatches =
    attr: patches:
    let
      bad = lib.filter (p: !(p ? file && p ? reason)) patches;
    in
    if bad == [ ] then
      patches
    else
      throw "TVP: ${attr} has patches missing `file` or `reason`. A patch states what it changes and why.";

  # A package that installs an upstream binary rather than building from source.
  # `needs` states what would replace it.
  checkBlob =
    attr: blob:
    if !(blob ? reason && blob ? needs) then
      throw "TVP: ${attr} declares `blob` and must state both `reason` and `needs`"
    else
      blob;

  # `base` is required of every definition rather than defaulted per package.
  # There are a few dozen definitions in the whole repo, so stating it is cheap,
  # and a definition that silently landed on the wrong ground would be invisible
  # while a missing one fails to evaluate. `null` says the builder is not on a
  # base at all, which is a fact worth declaring rather than inferring.
  checkDef =
    attr: entry:
    if !(entry ? def) then
      throw "TVP: ${attr} has no `def`. A version names a definition from its package's `defs`."
    else if !(entry.def ? base) then
      throw "TVP: the definition behind ${attr} declares no `base`. Use `null` if the builder takes no stdenv."
    else
      entry.def;

  checkStatus =
    attr: status:
    if !(lib.elem status.level statusLevels) then
      throw "TVP: ${attr} has status level '${status.level}'; expected one of ${lib.concatStringsSep ", " statusLevels}"
    else if status.level != "ok" && !(status ? reason && status ? needs) then
      throw "TVP: ${attr} is '${status.level}' and must declare both `reason` and `needs`"
    else if
      status.level == "degraded" && !(status ? capability) && (status.knownTestFailures or [ ]) == [ ]
    then
      throw "TVP: ${attr} is degraded but anchors the claim to nothing. Name the `capability` that is off, or the `knownTestFailures` the defect causes."
    else if (status.knownTestFailures or [ ]) != [ ] && status.level == "ok" then
      throw "TVP: ${attr} declares knownTestFailures but claims level 'ok'"
    else
      status;

  # `packageMeta` describes the package rather than a version — one upstream
  # index serves all nine Rubies. It is written once in the package's
  # default.nix and copied onto each version's passthru, because the package set
  # is flat and versions are the only things with a name in it.
  mkVersions =
    {
      # What this package still borrows from nixpkgs. Anything a builder declares
      # that is neither here nor in the version table fails to evaluate.
      infra,
      pname,
      versionTable,
      extraArgs ? { },
      packageMeta ? { },
    }:
    lib.mapAttrs' (
      version: rawEntry:
      let
        attr = versions.attrName pname version;
        entry = checkEntry attr rawEntry;
        recipe = checkDef attr entry;

        definition =
          recipe.name
            or (throw "TVP: the definition behind ${attr} carries no name. Wrap the package's `defs` in `tvpLib.packages.mkDefs`.");

        status = checkStatus attr (entry.status or { level = "ok"; });
        patches = checkPatches attr (recipe.patches or [ ]);
        inherit (recipe) base;

        builder = import recipe.builder;

        pkg = lib.makeOverridable builder (
          builtins.intersectAttrs (builtins.functionArgs builder) infra
          // {
            inherit version;
            inherit (entry) sha256;
          }
          # The whole base mechanism. Builders already take `stdenv` and already
          # call `stdenv.mkDerivation`, so naming it here is the only edit a base
          # ever needs — no builder mentions bases at all.
          #
          # A null base means the builder does not take a stdenv because it
          # delegates to a nixpkgs helper, and is therefore not on a TVP base at
          # all. That has to be declared rather than inferred, and
          # `passthru.tvp.base` reports it as null.
          // lib.optionalAttrs (base != null) { inherit (base) stdenv; }
          // checkDeps attr recipe.deps
          // lib.optionalAttrs (patches != [ ]) { patches = map (p: p.file) patches; }
          // (recipe.opts or { })
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
                # The filename, so `builder-names` can compare it against the lowest
                # version that reaches it. A path here would print a store path.
                builder = baseNameOf recipe.builder;
                inherit definition;
                # Names only, for the same reason.
                infra = lib.attrNames infra;
              }
              // lib.optionalAttrs (patches != [ ]) {
                patches = map (p: {
                  inherit (p) reason;
                  file = baseNameOf p.file;
                }) patches;
              }
              // lib.optionalAttrs (recipe ? blob) { blob = checkBlob attr recipe.blob; };

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

{
  system ? "x86_64-linux", # currently unused?
  config ? { },
  pkgs, # TODO: nixpkgs check and abort if not or auto import channel
}:
let
  tvpLib = import ./lib { inherit (pkgs) lib; };

  # The ground packages are built on. Defined before `packages` because every
  # version table names one, and exposed on `tvp` so a version table can reach
  # it the same way it reaches `tvp.packages`.
  bases = import ./bases { inherit pkgs tvpLib; };

  packages = import ./pkgs { inherit pkgs tvp; };

  # Repo-wide invariants only. A package's own tests live at <pkg>.tests.*.
  checks = {
    packages-evaluate =
      let
        drvs = pkgs.lib.mapAttrsToList (
          name: pkg: "${name} ${builtins.unsafeDiscardStringContext pkg.drvPath}"
        ) packages;
      in
      pkgs.runCommand "tvp-packages-evaluate" { manifest = builtins.concatStringsSep "\n" drvs; } ''
        printf '%s\n' "$manifest" > "$out"
      '';

    # Makes "untested" unrepresentable rather than merely discouraged. A broken
    # package is exempt because it has no build to test — and it can only be
    # broken by declaring a reason and a fix, so that exemption is not a hiding
    # place.
    every-package-tested =
      let
        buildable = pkgs.lib.filterAttrs (_: p: (p.tvp.status.level or "ok") != "broken") packages;
        untested = pkgs.lib.filterAttrs (_: p: !(p ? tests) || p.tests == { }) buildable;
      in
      if untested == { } then
        pkgs.runCommand "tvp-check-every-package-tested"
          { tested = toString (builtins.length (builtins.attrNames buildable)); }
          ''
            printf '%s buildable packages, all with tests\n' "$tested" > "$out"
          ''
      else
        throw "TVP: packages with no tests: ${pkgs.lib.concatStringsSep ", " (pkgs.lib.attrNames untested)}";

    # A builder is named for the version it starts at and serves forward, so the
    # lowest version pointing at it must be the version it is named for. Nothing
    # enforced that, and descending moves the answer on every step: build-2.7.nix
    # served 2.2.0 upward for 85 versions before anyone noticed.
    #
    # Renaming is a finish-the-line step, so a stale name mid-descent is expected
    # and this failing is the reminder to do it before committing.
    builder-names =
      let
        # "2.7" is the name for a line whose lowest release is "2.7.0", so the
        # name has to be a component-wise prefix rather than equal.
        prefixOf =
          name: version:
          let
            n = builtins.splitVersion name;
            v = builtins.splitVersion version;
          in
          builtins.length n <= builtins.length v && pkgs.lib.take (builtins.length n) v == n;

        lower = a: b: if builtins.compareVersions a b < 0 then a else b;

        withBuilder = pkgs.lib.filterAttrs (_: p: (p.tvp.builder or null) != null) packages;

        groups = pkgs.lib.foldlAttrs (
          acc: _: p:
          let
            key = "${p.pname}/${p.tvp.builder}";
          in
          acc // { ${key} = if acc ? ${key} then lower acc.${key} p.version else p.version; }
        ) { } withBuilder;

        stale = pkgs.lib.filterAttrs (
          key: lowest:
          let
            file = pkgs.lib.last (pkgs.lib.splitString "/" key);
            name = pkgs.lib.removeSuffix ".nix" (pkgs.lib.removePrefix "build-" file);
          in
          !(prefixOf name lowest)
        ) groups;
      in
      if stale == { } then
        pkgs.runCommand "tvp-check-builder-names"
          { checked = toString (builtins.length (builtins.attrNames groups)); }
          ''
            printf '%s builders, each named for the lowest version it serves\n' "$checked" > "$out"
          ''
      else
        throw "TVP: builders serving a version below their name — rename them to the version they now start at:\n${
          pkgs.lib.concatStringsSep "\n" (
            pkgs.lib.mapAttrsToList (key: lowest: "  ${key} serves ${lowest}") stale
          )
        }";

    # A definition is named for the version where it first appears, so the lowest
    # version pointing at it must be the version it is named for. Unlike a
    # builder, a definition claims no forward range — dependencies and options
    # revert — so this is equality on the lowest version, not a prefix.
    definition-names =
      let
        lower = a: b: if builtins.compareVersions a b < 0 then a else b;

        named = pkgs.lib.filterAttrs (_: p: (p.tvp.definition or null) != null) packages;

        groups = pkgs.lib.foldlAttrs (
          acc: _: p:
          let
            key = "${p.pname}/${p.tvp.definition}";
          in
          acc // { ${key} = if acc ? ${key} then lower acc.${key} p.version else p.version; }
        ) { } named;

        stale = pkgs.lib.filterAttrs (
          key: lowest: pkgs.lib.last (pkgs.lib.splitString "/" key) != lowest
        ) groups;
      in
      if stale == { } then
        pkgs.runCommand "tvp-check-definition-names"
          { checked = toString (builtins.length (builtins.attrNames groups)); }
          ''
            printf '%s definitions, each named for the lowest version it serves\n' "$checked" > "$out"
          ''
      else
        throw "TVP: definitions named for a version above the lowest they serve:\n${
          pkgs.lib.concatStringsSep "\n" (
            pkgs.lib.mapAttrsToList (key: lowest: "  ${key} serves ${lowest}") stale
          )
        }";

    # `checkStatus` makes a degraded version name a capability; this makes the
    # name true. A status is a claim, and the only claim a machine can settle is
    # whether the capability it points at is actually off.
    #
    # The reverse does not follow and is deliberately not checked: a false
    # feature on an `ok` package may be a degradation or may be era-correct —
    # readline 2.x lost a shared library upstream shipped, while zlib before
    # 1.2.3.1 never had a .pc file to lose — and nothing computable tells those
    # apart.
    degraded-capability-is-off =
      let
        claimed = pkgs.lib.filterAttrs (
          _: p: (p.tvp.status.level or "ok") == "degraded" && (p.tvp.status ? capability)
        ) packages;

        wrong = pkgs.lib.filterAttrs (
          _: p:
          let
            name = p.tvp.status.capability;
            features = p.tvp.features or { };
          in
          !(features ? ${name}) || features.${name} != false
        ) claimed;
      in
      if wrong == { } then
        pkgs.runCommand "tvp-check-degraded-capability-is-off"
          { checked = toString (builtins.length (builtins.attrNames claimed)); }
          ''
            printf '%s degraded versions, each naming a capability that is declared off\n' "$checked" > "$out"
          ''
      else
        throw "TVP: degraded versions naming a capability that is not declared off:\n${
          pkgs.lib.concatStringsSep "\n" (
            pkgs.lib.mapAttrsToList (
              name: p:
              "  ${name} claims '${p.tvp.status.capability}', which the builder declares as ${
                  if (p.tvp.features or { }) ? ${p.tvp.status.capability} then "true" else "nothing at all"
                }"
            ) wrong
          )
        }";

    every-base-tested =
      let
        untested = pkgs.lib.filterAttrs (_: b: !(b ? tests) || b.tests == { }) bases;
      in
      if untested == { } then
        pkgs.runCommand "tvp-check-every-base-tested"
          { tested = toString (builtins.length (builtins.attrNames bases)); }
          ''
            printf '%s base attributes, all with tests\n' "$tested" > "$out"
          ''
      else
        throw "TVP: bases with no tests: ${pkgs.lib.concatStringsSep ", " (pkgs.lib.attrNames untested)}";

    # Holds bases/stdenv/make-derivation.nix at "vendored verbatim": TVP's
    # mkDerivation must still compute exactly what nixpkgs' does. Trimming what
    # TVP does not use is a deliberate, cache-invalidating step, and this check
    # failing is what distinguishes that from an accident.
    vendored-mkderivation-neutral =
      let
        probe =
          stdenv:
          (stdenv.mkDerivation (finalAttrs: {
            pname = "mkderivation-probe";
            version = "1";
            src = null;
            dontUnpack = true;
            configureFlags = [ "--probe" ];
            buildInputs = [ pkgs.zlib ];
            nativeBuildInputs = [ pkgs.pkg-config ];
            hardeningDisable = [ "format" ];
            enableParallelBuilding = true;
            installPhase = "mkdir -p $out";
          })).drvPath;
        tvp = probe bases.default.stdenv;
        upstream = probe pkgs.stdenv;
      in
      if tvp == upstream then
        pkgs.runCommand "tvp-check-mkderivation-neutral" { inherit tvp; } ''
          printf '%s\n' "$tvp" > "$out"
        ''
      else
        throw "TVP: vendored mkDerivation is no longer derivation-neutral:\n  nixpkgs ${upstream}\n  tvp     ${tvp}";

    # Only .nix files are copied, so local-only files never reach the store.
    formatting =
      let
        inherit (pkgs.lib) fileset;
        src = fileset.toSource {
          root = ./.;
          fileset = fileset.fileFilter (f: f.hasExt "nix") ./.;
        };
      in
      pkgs.runCommand "tvp-check-formatting" { nativeBuildInputs = [ pkgs.nixfmt-rfc-style ]; } ''
        nixfmt --check $(find ${src} -name '*.nix') 2>&1 | tee "$out"
        test ! -s "$out"
      '';
  };

  testBatches =
    builtins.mapAttrs
      (
        name: pkg:
        tvpLib.tests.mkBatch {
          inherit pkgs name;
          suite = pkg.tests;
        }
      )
      (
        pkgs.lib.filterAttrs (
          _: pkg: pkg ? tests && pkg.tests != { } && (pkg.tvp.status.level or "ok") != "broken"
        ) packages
      );

  # Deliberately not in `packages`: that attribute is the canonical package
  # universe, and tooling in it would also be subject to every-package-tested.
  tools = {
    provenance = pkgs.callPackage ./tools/provenance.nix {
      inherit packages;
      inherit tvpLib;
    };
    upstream = pkgs.callPackage ./tools/upstream.nix {
      inherit packages;
      inherit tvpLib;
    };
    neutral = pkgs.callPackage ./tools/neutral.nix {
      inherit packages;
      inherit tvpLib;
    };
    status = pkgs.callPackage ./tools/status.nix {
      inherit packages bases;
      inherit tvpLib;
    };
  };

  tvp = {
    inherit
      bases
      packages
      checks
      testBatches
      tools
      ;
    lib = tvpLib;
  };
in
tvp

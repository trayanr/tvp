# Repository-wide check registration. Package suites remain with their families.
{
  pkgs,
  tvp,
  tvpLib,
  canonical,
  bases,
  legacyBases,
  construction,
  recipes,
  familyEntrypoints,
  allVariantPackages,
  ownedCLI,
  runtimeRegistry,
}:
(import ../audits {
  inherit pkgs tvp;
  registry = runtimeRegistry;
})
// {
  build-concurrency = pkgs.writeText "tvp-build-concurrency-contracts" (
    builtins.toJSON (import ../lib/tests/build-concurrency.nix { inherit pkgs tvp; })
  );

  php-extensions = pkgs.writeText "tvp-php-extension-contracts" (
    builtins.toJSON (import ../lib/tests/php-extensions.nix { inherit pkgs tvp; })
  );
  php-extension-custom = import ../lib/tests/php-extension-custom.nix { inherit tvp; };

  node-build-python = import ../pkgs/runtimes/nodejs/tests/build-python.nix {
    context = tvp.packages.nodejs.testContext;
    python = tvp.packages.nodejs.specification.python;
  };

  shared-helper-filesystem = import ../lib/tests/shared-helper-filesystem.nix {
    inherit (pkgs) lib;
    builder = tvp.builder;
    base = bases.gcc_16.full;
  };

  shared-helpers = pkgs.writeText "tvp-shared-helper-contracts" (
    builtins.toJSON (import ../lib/tests/shared-helpers.nix { inherit (pkgs) lib; })
  );

  version-helpers = pkgs.writeText "tvp-version-helper-contracts" (
    builtins.toJSON (import ../lib/tests/version-helpers.nix { inherit (pkgs) lib; })
  );

  source-descriptors = pkgs.writeText "tvp-source-descriptor-contracts" (
    builtins.toJSON (import ../lib/tests/source-descriptors.nix { inherit (pkgs) lib; })
  );

  openssl-family = pkgs.writeText "tvp-openssl-family-contracts" (
    builtins.toJSON (import ../lib/tests/openssl-family.nix { inherit pkgs tvp; })
  );
  expat-family = pkgs.writeText "tvp-expat-family-contracts" (
    builtins.toJSON (import ../lib/tests/expat-family.nix { inherit pkgs tvp; })
  );
  dbm-yaml-families = pkgs.writeText "tvp-dbm-yaml-family-contracts" (
    builtins.toJSON (
      import ../pkgs/libraries/dbm-yaml-family-contracts.nix {
        inherit tvp;
        inherit (pkgs) lib;
      }
    )
  );
  acl-family = pkgs.writeText "tvp-acl-family-contracts" (
    builtins.toJSON (
      import ../lib/tests/acl-family.nix {
        inherit tvp;
        inherit (pkgs) lib;
      }
    )
  );
  parser-families = pkgs.writeText "tvp-parser-family-contracts" (
    builtins.toJSON (
      import ../pkgs/build-tools/parser-family-contracts.nix {
        inherit tvp;
        inherit (pkgs) lib;
      }
    )
  );
  regex-hash-families = pkgs.writeText "tvp-regex-hash-family-contracts" (
    builtins.toJSON (import ../lib/tests/regex-hash-families.nix { inherit pkgs tvp; })
  );
  ffi-decimal-families = pkgs.writeText "tvp-ffi-decimal-family-contracts" (
    builtins.toJSON (
      import ../pkgs/libraries/ffi-decimal-family-contracts.nix {
        inherit tvp;
        inherit (pkgs) lib;
      }
    )
  );
  recipe-splits = pkgs.writeText "tvp-recipe-splits.json" (
    builtins.toJSON (tvpLib.recipeSplits.enforce tvp.recipeSplitReport)
  );
  upstream-test-isolation = pkgs.writeText "tvp-upstream-test-isolation.json" (
    builtins.toJSON (tvpLib.upstreamTestIsolation.enforce tvp.upstreamIsolationReport)
  );
  upstream-test-isolation-contracts = import ../lib/tests/upstream-test-isolation.nix {
    inherit pkgs tvp;
  };
  openssl-upstream-isolation-contracts = import ../lib/tests/openssl-upstream-isolation.nix {
    inherit pkgs tvp;
  };
  recipe-split-contracts = import ../lib/tests/recipe-splits.nix { inherit pkgs tvp; };
  upstream-tracking = import ../tools/upstream/tests {
    inherit pkgs tvp ownedCLI;
    testDeps = {
      inherit (tvp.packages)
        bash
        coreutils
        git
        gnugrep
        ;
      inherit (pkgs) jq;
    };
  };
  bootstrap-audit-contracts = import ../bootstrap/check.nix { inherit tvp; };
  dependency-inventory =
    pkgs.runCommand "tvp-dependency-inventory-tests"
      {
        nativeBuildInputs = [
          tvp.packages.python_3
          tvp.tools.dependencies
        ];
      }
      ''
        tvp-dependencies --help > /dev/null
        cp ${../tools/dependencies/report.py} report.py
        cp ${../tools/dependencies/test_report.py} test_report.py
        cp ${../tools/dependencies/recursive.py} recursive.py
        cp ${../tools/dependencies/test_recursive.py} test_recursive.py
        python3 -m unittest -v test_report test_recursive >&2
        printf '%s\n' 'Dependency inventory contracts passed.' > "$out"
      '';
  dependency-policy =
    let
      unexplained = pkgs.lib.filter (
        edge:
        builtins.elem edge.scope [
          "ordinary"
          "public-variant"
        ]
        && (edge.selection.kind or "unknown") == "exact"
        && (edge.reason == null || edge.reason == "")
      ) tvp.dependencyInventory.edges;
    in
    if builtins.hasContext (builtins.toJSON tvp.dependencyInventory) then
      throw "TVP: dependency inventory must discard build contexts."
    else if unexplained != [ ] then
      throw "TVP: unexplained ordinary exact dependency selections: ${
        pkgs.lib.concatStringsSep ", " (map (edge: "${edge.consumer}/${edge.dependency}") unexplained)
      }"
    else
      pkgs.writeText "tvp-dependency-policy" "No unexplained ordinary exact dependency selections.\n";
  dependency-selectors = import ../lib/tests/selectors.nix { inherit pkgs tvp; };
  build-steps =
    let
      contracts = import ../lib/tests/build-steps.nix;
    in
    pkgs.writeText "tvp-build-step-contracts" (builtins.toJSON contracts);
  build-step-runner = import ../lib/tests/build-step-runner { inherit pkgs tvp; };
  named-outputs = import ../lib/tests/named-outputs.nix { inherit pkgs tvp; };
  uniform-package-families = pkgs.writeText "tvp-uniform-package-family-contracts" (
    builtins.toJSON (import ../lib/tests/uniform-package-families.nix { inherit familyEntrypoints; })
  );
  ordinary-family = pkgs.writeText "tvp-ordinary-family-contracts" (
    builtins.toJSON (import ../lib/tests/family.nix { inherit (pkgs) lib; })
  );
  tool-providers = pkgs.writeText "tvp-tool-provider-contracts" (
    builtins.toJSON (import ../lib/tests/tool-providers.nix { inherit (pkgs) lib; })
  );
  split-named-outputs = import ../lib/tests/split-named-outputs.nix { inherit pkgs tvp; };
  output-checks = import ../lib/tests/output-checks.nix {
    inherit (pkgs) lib;
    inherit (tvp.packages) bash coreutils;
  };
  gcc-target-tools = pkgs.writeText "tvp-gcc-target-tool-contracts" (
    builtins.toJSON (import ../lib/tests/gcc-target-tools.nix { inherit (pkgs) lib; })
  );
  effective-inputs = pkgs.writeText "tvp-effective-input-contracts" (
    builtins.toJSON (import ../lib/tests/effective-inputs.nix { inherit pkgs tvp; })
  );
  family-test-factories = import ../lib/tests/family-test-factories.nix {
    inherit pkgs tvp;
    inherit recipes;
  };
  # Keep fixture outputs individually visible to plan/output publication.
  named-outputs-validation = tvp.checks.named-outputs.passthru.validation;
  named-outputs-bin = tvp.checks.named-outputs.passthru.binary;
  named-outputs-validation-selected = tvp.checks.named-outputs.passthru.validation.validation;
  named-outputs-bin-selected = tvp.checks.named-outputs.passthru.binary.bin;
  named-outputs-validation-rebound = tvp.checks.named-outputs.passthru.changed;
  named-outputs-bin-rebound = tvp.checks.named-outputs.passthru.binChanged;
  owned-base = pkgs.writeText "tvp-owned-base-contracts" (
    builtins.toJSON (
      import ../lib/tests/owned-base.nix {
        inherit (pkgs) lib;
        inherit (tvp) builder;
      }
    )
  );
  base-aliases = pkgs.writeText "tvp-base-alias-contracts" (
    builtins.toJSON (import ../bases/tests/aliases.nix { inherit (pkgs) lib; })
  );
  base-compatibility = pkgs.writeText "tvp-base-compatibility-contracts" (
    builtins.toJSON (
      import ../lib/tests/base-compatibility.nix {
        inherit (pkgs) lib;
        inherit (tvp) builder;
      }
    )
  );
  base-shared-tests = pkgs.writeText "tvp-base-shared-test-contracts" (
    builtins.toJSON (
      import ../lib/tests/base-shared-tests.nix {
        inherit (pkgs) lib;
        inherit (tvp) builder;
      }
    )
  );
  base-tiers = pkgs.writeText "tvp-base-tier-contracts" (
    builtins.toJSON (
      import ../lib/tests/base-tiers.nix {
        inherit (pkgs) lib;
        inherit (tvp) builder;
      }
    )
  );
  zlib-family = pkgs.writeText "tvp-zlib-family-contracts" (
    builtins.toJSON (import ../pkgs/libraries/zlib/tests/source-contracts.nix { inherit pkgs tvp; })
  );
  xz-family = pkgs.writeText "tvp-xz-family-contracts" (
    builtins.toJSON (import ../lib/tests/xz-family.nix { inherit pkgs tvp; })
  );
  gzip-bzip2-families = pkgs.writeText "tvp-gzip-bzip2-family-contracts" (
    builtins.toJSON (import ../lib/tests/gzip-bzip2-families.nix { inherit pkgs tvp; })
  );
  autotools-family = pkgs.writeText "tvp-autotools-family-contracts" (
    builtins.toJSON (import ../lib/tests/autotools-family.nix { inherit pkgs tvp; })
  );
  bzip2-source = import ../lib/tests/bzip2-source.nix { inherit tvp; };
  automake-family = pkgs.writeText "tvp-automake-family-contracts" (
    builtins.toJSON (import ../lib/tests/automake-family.nix { inherit pkgs tvp; })
  );
  libtool-family = pkgs.writeText "tvp-libtool-family-contracts" (
    builtins.toJSON (import ../lib/tests/libtool-family.nix { inherit pkgs tvp; })
  );
  ninja-family = pkgs.writeText "tvp-ninja-family-contracts" (
    builtins.toJSON (import ../lib/tests/ninja-family.nix { inherit pkgs tvp; })
  );
  pkg-config-family = pkgs.writeText "tvp-pkg-config-family-contracts" (
    builtins.toJSON (import ../lib/tests/pkg-config-family.nix { inherit pkgs tvp; })
  );
  m4-family = pkgs.writeText "tvp-m4-family-contracts" (
    builtins.toJSON (import ../lib/tests/m4-family.nix { inherit pkgs tvp; })
  );
  gnumake-family = pkgs.writeText "tvp-gnumake-family-contracts" (
    builtins.toJSON (import ../lib/tests/gnumake-family.nix { inherit pkgs tvp; })
  );
  compiler-library-construction = pkgs.writeText "tvp-compiler-library-construction-contracts" (
    builtins.toJSON (import ../lib/tests/compiler-library-construction.nix { inherit pkgs tvp; })
  );
  mpc-family = pkgs.writeText "tvp-mpc-family-contracts" (
    builtins.toJSON (import ../lib/tests/mpc-family.nix { inherit pkgs tvp; })
  );
  isl-family = pkgs.writeText "tvp-isl-family-contracts" (
    builtins.toJSON (import ../lib/tests/isl-family.nix { inherit pkgs tvp; })
  );
  gmp-family = pkgs.writeText "tvp-gmp-family-contracts" (
    builtins.toJSON (import ../lib/tests/gmp-family.nix { inherit pkgs tvp; })
  );
  mpfr-family = pkgs.writeText "tvp-mpfr-family-contracts" (
    builtins.toJSON (import ../lib/tests/mpfr-family.nix { inherit pkgs tvp; })
  );
  source-gnu-hardening = import ../bases/source-gnu/hardening/check.nix { inherit tvp; };
  owned-builder = import ../lib/tests/owned-builder.nix { inherit pkgs tvp; };
  owned-tests = (import ../lib/tests/owned-tests-native.nix { }).check;
  owned-mpc = import ../lib/tests/owned-mpc.nix { inherit pkgs tvp; };
  owned-json-c = import ../lib/tests/owned-json-c.nix { inherit pkgs tvp; };
  owned-ruby = import ../lib/tests/owned-ruby.nix { inherit pkgs tvp; };
  owned-zstd = import ../lib/tests/owned-zstd.nix { inherit pkgs tvp; };
  remaining-adapter-profiles = pkgs.writeText "tvp-remaining-adapter-profile-contracts" (
    builtins.toJSON (import ../lib/tests/remaining-adapter-profiles.nix { inherit pkgs tvp; })
  );
  owned-fontconfig = import ../lib/tests/owned-fontconfig.nix { inherit pkgs tvp; };
  owned-x11 = import ../lib/tests/owned-x11.nix { inherit pkgs tvp; };
  jdk-support-splits = import ../lib/tests/jdk-support-splits.nix { inherit pkgs tvp; };
  owned-jdk-source-stage = import ../lib/tests/jdk-source-stage { inherit pkgs tvp; };
  owned-x11-extensions = import ../lib/tests/owned-x11-extensions.nix { inherit pkgs tvp; };
  owned-catalogue = import ../lib/tests/owned-catalogue.nix { inherit pkgs tvp; };
  native-recipes = import ../lib/tests/native-recipes.nix { inherit pkgs tvp; };
  native-output = import ../lib/tests/native-output.nix { inherit pkgs tvp; };
  reusable-output = import ../lib/tests/reusable-output.nix { inherit pkgs tvp; };
  output-selection = (import ../lib/tests/output-selection.nix { }).check;
  ruby-build-steps = import ../lib/tests/ruby-build-steps.nix { inherit pkgs tvp; };
  native-meson = import ../lib/tests/native-meson.nix { inherit pkgs tvp; };
  native-make = import ../lib/tests/native-make.nix { inherit pkgs tvp; };
  step-temporary-cleanup = import ../lib/tests/step-temporary-cleanup.nix { inherit pkgs tvp; };
  base-selection = import ../bases/tests/selection.nix { inherit pkgs tvp construction; };
  gcc13-stage-contexts = import ../bases/tests/gcc13-contexts.nix { inherit tvp; };
  owned-android = import ../lib/tests/android { inherit pkgs tvp; };
  android-sdk-composition = import ../sdks/tests/android.nix { inherit tvp; };
  bootstrap-independent = import ../bases/tests/bootstrap.nix { inherit pkgs tvp; };
  source-base-providers = pkgs.writeText "tvp-source-base-provider-contracts" (
    builtins.toJSON (
      import ../bases/tests/provider-origin.nix {
        inherit (pkgs) lib;
        inherit tvp;
      }
    )
  );
  source-gcc13-composition = pkgs.writeText "tvp-source-gcc13-composition-contracts" (
    builtins.toJSON (import ../bases/tests/source-gcc13.nix { })
  );
  cli-packaging = import ../tools/lib/tests { inherit pkgs tvp ownedCLI; };
  test-runner = pkgs.callPackage ../tools/test-runner/tests { python3 = tvp.packages.python_3; };
  native-platform-interface = import ../bases/tests/platform.nix {
    inherit pkgs tvpLib bases;
    inherit legacyBases;
  };
  variants-evaluate =
    let
      buildable = pkgs.lib.filterAttrs (
        _: p: (p.tvp.status.level or "ok") != "broken"
      ) allVariantPackages;
      untested = pkgs.lib.filterAttrs (_: p: !(p ? tests) || p.tests == { }) buildable;
      manifest = pkgs.lib.mapAttrsToList (
        name: p: "${name} ${builtins.unsafeDiscardStringContext p.drvPath}"
      ) allVariantPackages;
    in
    if untested != { } then
      throw "TVP: variants with no tests: ${pkgs.lib.concatStringsSep ", " (pkgs.lib.attrNames untested)}"
    else
      pkgs.runCommand "tvp-variants-evaluate" { manifest = builtins.concatStringsSep "\n" manifest; } ''
        printf '%s\n' "$manifest" > "$out"
      '';
  packages-evaluate =
    let
      drvs = pkgs.lib.mapAttrsToList (
        name: pkg: "${name} ${builtins.unsafeDiscardStringContext pkg.drvPath}"
      ) canonical;
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
      buildable = pkgs.lib.filterAttrs (_: p: (p.tvp.status.level or "ok") != "broken") canonical;
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

      withBuilder = pkgs.lib.filterAttrs (_: p: (p.tvp.builder or null) != null) canonical;

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
          name = pkgs.lib.removeSuffix "-native" (
            pkgs.lib.removeSuffix "-current" (
              pkgs.lib.removePrefix "owned-" (pkgs.lib.removeSuffix ".nix" (pkgs.lib.removePrefix "build-" file))
            )
          );
          versioned = builtins.match "[0-9]+([.-][0-9]+)*" name != null;
        in
        versioned && !(prefixOf name lowest)
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

      named = pkgs.lib.filterAttrs (_: p: (p.tvp.definition or null) != null) canonical;

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
      ) canonical;

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
      untested = pkgs.lib.filterAttrs (_: b: !(b ? tests) || b.tests == { }) legacyBases;
    in
    if untested == { } then
      pkgs.runCommand "tvp-check-every-base-tested"
        { tested = toString (builtins.length (builtins.attrNames legacyBases)); }
        ''
          printf '%s base attributes, all with tests\n' "$tested" > "$out"
        ''
    else
      throw "TVP: bases with no tests: ${pkgs.lib.concatStringsSep ", " (pkgs.lib.attrNames untested)}";

  # Only .nix files are copied, so local-only files never reach the store.
  formatting =
    let
      inherit (pkgs.lib) fileset;
      src = fileset.toSource {
        root = ../.;
        fileset = fileset.fileFilter (f: f.hasExt "nix") ../.;
      };
    in
    pkgs.runCommand "tvp-check-formatting" { nativeBuildInputs = [ pkgs.nixfmt-rfc-style ]; } ''
      nixfmt --check $(find ${src} -name '*.nix') 2>&1 | tee "$out"
      test ! -s "$out"
    '';
}

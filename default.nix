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
  baseSet = import ./bases {
    inherit pkgs tvpLib tvp;
    inherit (universe) recipes;
  };
  bases = baseSet.bases;
  construction = baseSet.construction;

  universe = import ./pkgs { inherit pkgs tvp; };

  # An alias may shadow a canonical name here, deliberately: `openssl_1_1_1` is
  # the newest 1.1.1x. The shadowed release keeps its exact name in `canonical`,
  # which is what every tool and check reads.
  canonical = universe.canonical;
  packages =
    pkgs.lib.mapAttrs (
      selector: package:
      tvpLib.packages.tagSelection (
        package.__tvpSelection
        // {
          namespace = "packages";
          inherit selector;
          publicFallback = true;
        }
      ) package
    ) canonical
    // universe.aliases;
  variants = universe.variants;
  allVariantPackages =
    tvpLib.packages.merge (
      pkgs.lib.mapAttrs (
        profile: entries:
        pkgs.lib.mapAttrs' (
          name: package: pkgs.lib.nameValuePair "bootstrap-${profile}-${name}" package
        ) entries
      ) construction.variants
    )
    // variantPackages;
  variantPackages = tvpLib.packages.merge (
    pkgs.lib.mapAttrs (
      profile: entries:
      pkgs.lib.mapAttrs' (
        name: package: pkgs.lib.nameValuePair "variant-${profile}-${name}" package
      ) entries
    ) variants
  );

  runtimeRegistry = tvpLib.provenance.registry {
    inherit
      canonical
      variants
      bases
      construction
      ;
    compositions = tvp.android.profiles;
  };

  # Repo-wide invariants only. A package's own tests live at <pkg>.tests.*.
  checks =
    (import ./audits {
      inherit pkgs tvp;
      registry = runtimeRegistry;
    })
    // {
      upstream-tracking = import ./tools/upstream/tests {
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
      construction-preserved = import ./bases/tests/construction.nix { inherit pkgs tvp; };
      bootstrap-audit-contracts = import ./bootstrap/check.nix { inherit tvp; };
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
            cp ${./tools/dependencies/report.py} report.py
            cp ${./tools/dependencies/test_report.py} test_report.py
            cp ${./tools/dependencies/recursive.py} recursive.py
            cp ${./tools/dependencies/test_recursive.py} test_recursive.py
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
      dependency-selectors = import ./lib/tests/selectors.nix { inherit pkgs tvp; };
      build-steps =
        let
          contracts = import ./lib/tests/build-steps.nix;
        in
        pkgs.writeText "tvp-build-step-contracts" (builtins.toJSON contracts);
      build-step-runner = import ./lib/tests/build-step-runner { inherit pkgs tvp; };
      named-outputs = import ./lib/tests/named-outputs.nix { inherit pkgs tvp; };
      legacy-test-factories = import ./lib/tests/legacy-test-factories.nix {
        inherit pkgs tvp;
        inherit (universe) recipes;
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
          import ./lib/tests/owned-base.nix {
            inherit (pkgs) lib;
            inherit (tvp) builder;
          }
        )
      );
      owned-builder = import ./lib/tests/owned-builder.nix { inherit pkgs tvp; };
      owned-tests = (import ./lib/tests/owned-tests-native.nix { }).check;
      owned-mpc = import ./lib/tests/owned-mpc.nix { inherit pkgs tvp; };
      owned-json-c = import ./lib/tests/owned-json-c.nix { inherit pkgs tvp; };
      owned-ruby = import ./lib/tests/owned-ruby.nix { inherit pkgs tvp; };
      owned-zstd = import ./lib/tests/owned-zstd.nix { inherit pkgs tvp; };
      owned-fontconfig = import ./lib/tests/owned-fontconfig.nix { inherit pkgs tvp; };
      owned-catalogue = import ./lib/tests/owned-catalogue.nix { inherit pkgs tvp; };
      native-recipes = import ./lib/tests/native-recipes.nix { inherit pkgs tvp; };
      native-output = import ./lib/tests/native-output.nix { inherit pkgs tvp; };
      reusable-output = import ./lib/tests/reusable-output.nix { inherit pkgs tvp; };
      ruby-build-steps = import ./lib/tests/ruby-build-steps.nix { inherit pkgs tvp; };
      native-meson = import ./lib/tests/native-meson.nix { inherit pkgs tvp; };
      native-make = import ./lib/tests/native-make.nix { inherit pkgs tvp; };
      step-temporary-cleanup = import ./lib/tests/step-temporary-cleanup.nix { inherit pkgs tvp; };
      base-selection = import ./bases/tests/selection.nix { inherit pkgs tvp construction; };
      android-sdk-composition = import ./sdks/tests/android.nix { inherit tvp; };
      bootstrap-independent = import ./bases/tests/bootstrap.nix {
        inherit pkgs;
        parent = construction.bases.gcc13;
        owned = construction.bases.gcc13-owned;
        packages = construction.variants.gcc13;
      };
      cli-packaging = import ./tools/lib/tests { inherit pkgs tvp ownedCLI; };
      test-runner = pkgs.callPackage ./tools/test-runner/tests { python3 = tvp.packages.python_3; };
      native-platform-interface = import ./bases/tests/platform.nix { inherit pkgs tvpLib bases; };
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
            builtins.unsafeDiscardStringContext
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
          # These are identities to compare, not build dependencies. Keeping
          # their context requires an unwritten probe drv during read-only checks.
          # Compare the borrowed environment to its original Nixpkgs builder.
          # The default now constructs a deliberately different owned environment.
          tvp = probe construction.bases.gcc13.stdenv;
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

  # Keep this mapping lazy: latest selection must not enumerate historical suites
  # just to find the selected batch. Full coverage retains its existing filter.
  packageTestBatches = builtins.mapAttrs (
    name: pkg:
    (
      if pkg ? testContext then
        pkg.testContext.mkBatch
      else
        args: tvpLib.tests.mkBatch (args // { inherit pkgs; })
    )
      {
        inherit name;
        suite = pkg.tests;
      }
  ) canonical;

  testBatchEntries = tvpLib.packages.merge {
    packages = pkgs.lib.filterAttrs (
      name: _:
      let
        pkg = canonical.${name};
      in
      pkg ? tests && pkg.tests != { } && (pkg.tvp.status.level or "ok") != "broken"
    ) packageTestBatches;
    bases = pkgs.lib.mapAttrs' (
      name: base:
      pkgs.lib.nameValuePair "base-${name}" (
        tvpLib.tests.mkBatch {
          inherit pkgs;
          name = "base-${name}";
          suite = base.tests;
        }
      )
    ) (pkgs.lib.filterAttrs (name: base: base.name == name) bases);
    bootstrapBases = pkgs.lib.mapAttrs' (
      name: base:
      pkgs.lib.nameValuePair "bootstrap-base-${name}" (
        tvpLib.tests.mkBatch {
          inherit pkgs;
          name = "bootstrap-base-${name}";
          suite = base.tests;
        }
      )
    ) construction.bases;
    variants = pkgs.lib.mapAttrs (
      name: package:
      (
        if package ? testContext then
          package.testContext.mkBatch
        else
          args: tvpLib.tests.mkBatch (args // { inherit pkgs; })
      )
        {
          inherit name;
          suite = package.tests;
        }
    ) (pkgs.lib.filterAttrs (_: p: (p.tvp.status.level or "ok") != "broken") allVariantPackages);
  };

  testBatches = testBatchEntries // {
    all = tvpLib.tests.mkAll {
      inherit pkgs checks;
      batches = testBatchEntries;
    };
  };

  # Separate from testBatches: the full plan enumerates every entry but `all`.
  # Reuse each package's existing testContext batch without reconstructing it.
  latestSelection = tvpLib.tests.selectLatest {
    inherit canonical packages;
    batches = packageTestBatches;
  };
  latestTests = latestSelection // {
    all = tvpLib.tests.mkLatest {
      context = tvpLib.tests.fromPackage {
        builder = tvp.builder;
        package = packages.coreutils;
      };
      selection = latestSelection;
    };
  };

  # Deliberately not in `packages`: that attribute is the canonical package
  # universe, and tooling in it would also be subject to every-package-tested.
  ownedCLI = import ./tools/lib/owned-cli.nix {
    inherit (pkgs) lib;
    inherit (tvp.packages) bash coreutils;
    shellcheck = pkgs.shellcheck-minimal;
    platform = bases.default.platform;
  };
  tools = {
    dependencies = pkgs.callPackage ./tools/dependencies {
      python3 = tvp.packages.python_3;
      inherit ownedCLI;
    };
    testRunner = pkgs.callPackage ./tools/test-runner {
      python3 = tvp.packages.python_3;
      inherit ownedCLI;
    };
    provenance = pkgs.callPackage ./tools/provenance.nix {
      inherit ownedCLI;
      coreutils = tvp.packages.coreutils;
      gawk = tvp.packages.gawk;
      gnused = tvp.packages.gnused;
      packages = canonical;
      inherit tvpLib variantPackages;
      registry = runtimeRegistry;
    };
    upstream = pkgs.callPackage ./tools/upstream.nix {
      inherit ownedCLI;
      coreutils = tvp.packages.coreutils;
      curl = tvp.packages.curl;
      git = tvp.packages.git;
      gnugrep = tvp.packages.gnugrep;
      gnused = tvp.packages.gnused;
      packages = canonical;
      inherit tvpLib;
    };
    neutral = pkgs.callPackage ./tools/neutral.nix {
      inherit ownedCLI;
      coreutils = tvp.packages.coreutils;
      gawk = tvp.packages.gawk;
      python3 = tvp.packages.python_3;
      packages = canonical;
      inherit tvpLib;
      graph = tvp.graph;
    };
    status = pkgs.callPackage ./tools/status.nix {
      inherit ownedCLI;
      coreutils = tvp.packages.coreutils;
      gnugrep = tvp.packages.gnugrep;
      gnused = tvp.packages.gnused;
      packages = canonical;
      inherit bases tvpLib;
    };
  };

  tvp = {
    dependencyRoots = import ./lib/dependency-roots.nix {
      inherit (pkgs) lib;
      inherit tools checks;
      graph = tvpLib.graph.snapshot {
        includeRootMetadata = true;
        inherit
          canonical
          variants
          bases
          construction
          ;
        compositions = tvp.android.profiles;
      };
      inventory = tvp.dependencyInventory;
      registry = runtimeRegistry;
      borrowed = {
        inherit (pkgs) jq shellcheck-minimal;
      };
      borrowedSource = toString pkgs.path;
    };
    dependencyInventory = import ./lib/dependencies.nix {
      inherit
        pkgs
        canonical
        variants
        construction
        ;
      compositions = tvp.android.profiles;
      buildTestSupport = {
        build-step-runner = {
          inherit (tvp.packages)
            bash
            coreutils
            zlib
            libffi
            ;
          environment = bases.default.stdenv;
          compiler = bases.default.stdenv.cc;
          python = tvp.packages.python_3;
        };
        named-outputs =
          {
            inherit (tvp.packages) bash coreutils;
          }
          // pkgs.lib.listToAttrs (
            pkgs.lib.imap0 (
              i: p: pkgs.lib.nameValuePair "floor${toString i}" p
            ) bases.default.stdenv.initialPath
          );
        reusable-output = {
          inherit (tvp.packages) bash;
          python = tvp.packages.python_3;
          binutils = tvp.packages.binutils_2;
          environment = bases.default.stdenv;
          compiler = bases.default.stdenv.cc;
        };
        ruby-build-steps = {
          inherit (tvp.packages) gzip;
          python = tvp.packages.python_3;
          binutils = tvp.packages.binutils_2;
          patchelf = tvp.packages.patchelf_0;
          environment = bases.default.stdenv;
          compiler = bases.default.stdenv.cc;
        };
        audit-contracts.python = tvp.packages.python_3;
        bootstrap-audit-contracts = {
          inherit (tvp.packages) bash coreutils;
          python = tvp.packages.python_3;
          environment = bases.default.stdenv;
          compiler = bases.default.stdenv.cc;
        };
        owned-mpc = {
          mpc = tvp.canonical.mpc_1_4_1;
          compatibleMpfr = tvp.packages.mpfr_4_2_1;
          inherit (tvp.packages)
            bash
            coreutils
            pkg-config
            ;
          gnumake = tvp.canonical.mpc_1_4_1.tvp.deps.gnumake;
          patchelf = tvp.canonical.mpc_1_4_1.tvp.deps.patchelf;
          grep = tvp.canonical.mpc_1_4_1.tvp.deps.grep;
          environment = bases.default.stdenv;
          compiler = bases.default.stdenv.cc;
        };
        owned-json-c = {
          json = tvp.packages.json-c_0;
          inherit (tvp.packages)
            bash
            coreutils
            cmake
            gnumake
            pkg-config
            ;
          patchelf = tvp.packages.patchelf_0;
          environment = bases.default.stdenv;
          compiler = bases.default.stdenv.cc;
        };
        owned-ruby = {
          ruby = tvp.canonical.ruby_4_0_6;
          compatibleZlib = tvp.packages.zlib_1_3_1;
          inherit (tvp.packages) bash coreutils;
          make = tvp.packages.gnumake;
          pkgConfig = tvp.packages.pkg-config;
          python = tvp.packages.python-build_3;
          sed = tvp.packages.gnused;
          environment = bases.default.stdenv;
          compiler = bases.default.stdenv.cc;
        };
        owned-zstd = {
          inherit (tvp.packages) bash coreutils;
          pkgConfig = tvp.packages.pkg-config;
          zstd = tvp.packages.zstd_1;
          compatibleZlib = tvp.packages.zlib_1_3_1;
          compatibleXz = tvp.packages.xz_5_6_4;
          environment = bases.default.stdenv;
          compiler = bases.default.stdenv.cc;
        };
        owned-fontconfig = {
          inherit (tvp.packages) bash coreutils;
          pkgConfig = tvp.packages.pkg-config;
          fontconfig = tvp.packages.fontconfig_2;
          compatibleExpat = pkgs.expat;
          environment = bases.default.stdenv;
          compiler = bases.default.stdenv.cc;
        };
        native-meson = {
          fontconfig = tvp.packages.fontconfig_2;
          inherit (tvp.packages)
            bash
            coreutils
            meson
            ninja
            pkg-config
            ;
          environment = bases.default.stdenv;
          compiler = bases.default.stdenv.cc;
        };
        dependency-inventory.python = tvp.packages.python_3;
        test-runner.python = tvp.packages.python_3;
        cli-interpreters.python = tvp.packages.python_3;
        cli-packaging = {
          inherit (tvp.packages) bash coreutils gnused;
          python = tvp.packages.python_3;
          shellcheck = pkgs.shellcheck-minimal;
        };
        cli-builders = {
          inherit (tvp.packages) bash coreutils;
          shellcheck = pkgs.shellcheck-minimal;
        };
        upstream-tracking = {
          inherit (tvp.packages)
            bash
            coreutils
            curl
            git
            gnugrep
            gnused
            ;
          jq = pkgs.jq;
        };
        cli-runtime = {
          bash = tvp.packages.bash;
          inherit (tvp.packages)
            coreutils
            curl
            git
            gnugrep
            gnused
            gawk
            ;
        };
        package-runtime-ownership.python = tvp.packages.python_3;
        package-runtime-ownership-latest.python = tvp.packages.python_3;
      };
    };
    graph = tvpLib.graph.snapshot {
      inherit
        canonical
        variants
        bases
        construction
        ;
      compositions = tvp.android.profiles;
    };
    android = import ./sdks/android.nix { inherit tvp; };
    inherit
      bases
      canonical
      packages
      variants
      checks
      testBatches
      latestTests
      tools
      ;
    builder = import ./lib/builder.nix { inherit (pkgs) lib; };
    lib = tvpLib;
  };
in
tvp

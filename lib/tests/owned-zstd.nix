{ pkgs, tvp }:
let
  inherit (pkgs) lib;
  inherit (tvp.builder) steps;
  p = tvp.canonical.zstd_1_5_7;
  base = p.specification.base;
  fixture = import ./prerequisite-fixture.nix {
    inherit tvp;
    package = p;
    tools = [
      tvp.packages.gnugrep
      tvp.packages.diffutils
    ];
  };
  pilot = tvp.variants.build-steps.zstd_1_5_7;
  zlib = tvp.packages.zlib_1_3_1;
  xz = tvp.packages.xz_5_6_4;
  runtime = p.editRuntime (_: {
    libraries = [
      zlib
      xz
    ];
  });
  disabled = (p.override { doCheck = false; }).editSteps (
    steps.replace "zstd.check" (_: {
      name = "zstd.check";
      enabled = false;
      tools = throw "disabled tools forced";
      libraries = throw "disabled libraries forced";
      run = throw "disabled command forced";
    })
  );
  insert = steps.insertAfter "zstd.build" [
    {
      name = "fixture.log";
      run = ":";
    }
  ];
  ordered = (p.editSteps insert).editRuntime (r: r);
  tagged = tvp.lib.packages.withConstraint { reason = "Zstd contract fixture."; } tvp.packages.zstd_1;
  taggedEdit = tagged.editRuntime (r: r);
  contracts = {
    generations =
      p.drvPath != pilot.drvPath
      && p.artifact.drvPath != pilot.artifact.drvPath
      && p.specification.base.name == "source-gnu-candidate"
      && pilot.specification.base.name == tvp.bases.default.name;
    pilotReplay =
      (pilot.override { }).drvPath == pilot.drvPath && (pilot.editSteps (x: x)).drvPath == pilot.drvPath;
    split = (steps.partition p.buildSteps).split;
    runtimeArtifact = p.artifact.drvPath == runtime.artifact.drvPath && p.drvPath != runtime.drvPath;
    compileInputsPreserved = p.specification.environment == runtime.specification.environment;
    noOp = (p.override { }).drvPath == p.drvPath;
    editableEnvironment =
      (p.edit (
        s:
        s
        // {
          environment = s.environment // {
            tools = s.environment.tools;
          };
        }
      )).drvPath == p.drvPath;
    orderedSpecification =
      ((p.edit (s: s // { meta.description = "first"; })).edit (
        s: s // { meta.description = s.meta.description + " second"; }
      )).meta.description == "first second";
    disabledFinalPayload =
      builtins.isString
        (p.editSteps (
          steps.append [
            {
              name = "fixture.disabled";
              enabled = false;
              tools = throw "disabled final tools";
              run = throw "disabled final body";
            }
          ]
        )).drvPath;
    functionOverride =
      (disabled.override (args: {
        doCheck = args.doCheck;
      })).drvPath == disabled.drvPath;
    inputOverride = (p.override { inherit zlib; }).tvp.deps.zlib.drvPath == zlib.drvPath;
    orderedReplay =
      (ordered.override { doCheck = false; }).drvPath
      == (((p.override { doCheck = false; }).editSteps insert).editRuntime (r: r)).drvPath;
    disabledLazy =
      !(lib.any (s: s.name == "zstd.check" || s.name == "zstd.prepare-tests") (
        steps.active (steps.partition disabled.buildSteps).first
      ));
    checkMetadata =
      !disabled.tvp.features.doCheck && builtins.length disabled.tvp.features.upstreamTests == 5;
    noOverrideAttrs = !(p ? overrideAttrs);
    unknownRejected = !(builtins.tryEval (p.override { unknown = true; }).drvPath).success;
    noSetup =
      !lib.hasInfix "/setup" (
        lib.concatStrings (p.buildStepRunner.childScripts ++ p.artifact.buildStepRunner.childScripts)
      );
    testsRebound =
      runtime.tests.compress.package.outPath == runtime.outPath
      && runtime.tests.compress.drvPath != p.tests.compress.drvPath;
    projections =
      runtime.out.tests.compress.drvPath == runtime.tests.compress.drvPath
      && (builtins.head runtime.all).tests.compress.drvPath == runtime.tests.compress.drvPath
      && runtime.passthru.tests.compress.drvPath == runtime.tests.compress.drvPath;
    provenance =
      runtime.tvp.customization.customized
      && runtime.__tvpSelection.kind == "override"
      && runtime.tvp.deps.zlib.drvPath == p.tvp.deps.zlib.drvPath;
    tags =
      lib.all
        (q: q.__tvpSelection.selector == "zstd_1" && q.__tvpSelection.reason == "Zstd contract fixture.")
        (
          [
            taggedEdit
            taggedEdit.out
          ]
          ++ taggedEdit.all
        );
    source = p.src.drvPath == pilot.src.drvPath;
    legacy = tvp.canonical.zstd_1_5_6 ? overrideAttrs && !(tvp.canonical.zstd_1_5_6 ? edit);
    publicRequirements = p.development.libraries == [ ];
    codecs = p.tvp.features.gzip && p.tvp.features.lzma && !p.tvp.features.lz4;
  };
  consumer = tvp.builder {
    recipe =
      {
        base,
        bash,
        coreutils,
        zstd,
        pkgConfig,
        grep,
        diffutils,
        version,
        src,
      }:
      {
        pname = "owned-zstd-consumer";
        inherit
          base
          bash
          coreutils
          version
          src
          ;
        plan = [
          (
            base.environment {
              tools = [
                pkgConfig
                grep
                diffutils
              ];
              libraries = [ zstd ];
            }
            // {
              name = "consumer.public";
              run = ''
                test "$($PKG_CONFIG --modversion libzstd)" = ${p.version}
                "$CC" $($PKG_CONFIG --cflags libzstd) ${../../pkgs/libraries/zstd/tests/fixtures/roundtrip.c} $($PKG_CONFIG --libs libzstd) -o shared
                "$CC" ${../../pkgs/libraries/zstd/tests/fixtures/roundtrip.c} ${zstd}/lib/libzstd.a -pthread -o static
                test "$(env -i ./shared)" = 'tvp preserved'
                test "$(env -i ./static)" = 'tvp preserved'
                env -i LD_DEBUG=libs ./shared 2> shared-loader
                grep -F 'calling init: ${zstd}/lib/libzstd.so.1' shared-loader
                printf 'selected codec data\n' > sample
                for format in zstd gzip xz; do
                  env -i LD_DEBUG=libs ${zstd}/bin/zstd --format="$format" -qc sample > "$format.data" 2> "$format.loader"
                  env -i ${zstd}/bin/zstd -dqc "$format.data" > "$format.out"
                  cmp sample "$format.out"
                done
                ${zstd.tvp.deps.gzip}/bin/gzip -dc gzip.data > gzip-external
                ${zstd.tvp.deps.xz}/bin/xz -dc xz.data > xz-external
                cmp sample gzip-external
                cmp sample xz-external
                grep -F 'calling init: ${
                  lib.getLib (builtins.elemAt zstd.runtime.libraries 0)
                }/lib/libz.so.1' gzip.loader
                grep -F 'calling init: ${
                  lib.getLib (builtins.elemAt zstd.runtime.libraries 1)
                }/lib/liblzma.so.5' xz.loader
                ${lib.optionalString (zstd.drvPath != p.drvPath) ''
                  if grep -F 'calling init: ${p.tvp.deps.zlib}/lib/' gzip.loader; then exit 1; fi
                  if grep -F 'calling init: ${p.tvp.deps.xz}/lib/' xz.loader; then exit 1; fi
                ''}
                for alias in unzstd zstdcat; do
                  env -i ${zstd}/bin/$alias -qc zstd.data > "$alias.out"
                  cmp sample "$alias.out"
                done
                env -i ${zstd}/bin/zstdmt -qc sample > mt.data
                env -i ${zstd}/bin/zstd -dqc mt.data > mt.out
                cmp sample mt.out
                if env -i ${zstd}/bin/zstd --format=lz4 -qc sample > lz4.data 2> lz4.err; then exit 1; fi
                mkdir "$out"
                cp shared static sample *.data *.out *.loader shared-loader "$out/"
              '';
            }
          )
        ];
      };
    args = {
      inherit base;
      inherit (tvp.packages) bash coreutils;
      zstd = p;
      pkgConfig = tvp.packages.pkg-config;
      grep = tvp.packages.gnugrep;
      diffutils = tvp.packages.diffutils;
      src = null;
      version = "1";
    };
    dependencyNames = [
      "zstd"
      "grep"
      "diffutils"
      "pkgConfig"
    ];
    metadata = { };
    selection.kind = "fixture";
    mkTests = _: { };
  };
  runtimeConsumer = consumer.override { zstd = runtime; };
  traceTool =
    name: binary: original:
    fixture {
      name = "zstd-selected-${name}";
      buildCommand = ''
        mkdir -p "$out/bin"
        cat > "$out/bin/${binary}" <<'SCRIPT'
        #!${tvp.packages.bash}/bin/bash
        printf '%s\n' '${name}' >> "$NIX_BUILD_TOP/selected-tools"
        exec ${original}/bin/${binary} "$@"
        SCRIPT
        chmod +x "$out/bin/${binary}"
      '';
    };
  selected =
    (p.override {
      gnused = traceTool "sed" "sed" p.tvp.deps.gnused;
      gnugrep = traceTool "grep" "grep" p.tvp.deps.gnugrep;
      diffutils = traceTool "diff" "diff" p.tvp.deps.diffutils;
      python = traceTool "python" "python3" p.tvp.deps.python;
    }).editSteps
      (
        steps.insertBefore "zstd.finalize" [
          {
            name = "fixture.selected-tools";
            tools = [ tvp.packages.gnugrep ];
            run = ''
              for tool in sed grep diff python; do
                grep -Fx "$tool" "$NIX_BUILD_TOP/selected-tools"
              done
              sort -u "$NIX_BUILD_TOP/selected-tools" > "$out/selected-tools"
            '';
          }
        ]
      );
  failed = lib.filter (n: !contracts.${n}) (lib.attrNames contracts);
in
assert failed == [ ] || throw "Owned Zstd contracts: ${lib.concatStringsSep ", " failed}";
(fixture {
  name = "tvp-owned-zstd-contracts";
  buildCommand = ''
    test -e ${selected}/selected-tools
    test -x ${consumer}/shared
    test -x ${runtimeConsumer}/shared
    test -e ${p.tests.helpers}
    test -e ${runtime.tests.helpers}
    test -e ${(import ./native-make.nix { inherit pkgs tvp; }).passthru.customized}/marker
    printf '%s\n' '${builtins.toJSON contracts}' > "$out"
  '';
})
// {
  passthru = {
    inherit
      contracts
      consumer
      runtime
      runtimeConsumer
      disabled
      selected
      ;
  };
}

{ pkgs, tvp }:
let
  inherit (pkgs) lib;
  helpers = import ../native-steps.nix { inherit lib; };
  steps = import ../build-steps.nix;
  p = tvp.variants.build-steps.fontconfig_2_18_3;
  # Wrappers retain the selected owned tools and record actual subprocess use.
  traceTool =
    name: tool:
    (tvp.bases.default.stdenv.mkDerivation {
      name = "meson-probe-${name}";
      buildCommand = ''
        mkdir -p "$out/bin"
        cat > "$out/bin/${name}" <<'SCRIPT'
        #!${tvp.packages.bash}/bin/bash
        printf '%s\n' '${name}' >> "$NIX_BUILD_TOP/tool-invocations"
        exec ${tool}/bin/${name} "$@"
        SCRIPT
        chmod +x "$out/bin/${name}"
      '';
    })
    // lib.optionalAttrs (tool ? buildEnvironment) { inherit (tool) buildEnvironment; };
  ninja = traceTool "ninja" tvp.packages.ninja;
  pkg-config = traceTool "pkg-config" tvp.packages.pkg-config;
  fixture = import ../native-recipe.nix { inherit lib; } {
    recipe =
      {
        base,
        bash,
        coreutils,
        meson,
        ninja,
        pkg-config,
      }:
      {
        pname = "native-meson-fixture";
        version = "1";
        src = null;
        inherit base bash coreutils;
        plan =
          [
            {
              name = "fixture.prepare";
              run = ''
                mkdir -p source/pc
                cat > source/meson.build <<'MESON'
                project('probe', 'c')
                dependency('tvp-probe', method: 'pkg-config')
                probe = executable('probe', 'probe.c', install: true)
                test('probe', probe)
                MESON
                printf 'int main(void) { return 0; }\n' > source/probe.c
                printf 'Name: tvp-probe\nDescription: isolated probe\nVersion: 1\n' > source/pc/tvp-probe.pc
              '';
            }
          ]
          ++ map
            (step: step // { run = ''export PKG_CONFIG_PATH="$TVP_SOURCE_ROOT/source/pc"'' + "\n" + step.run; })
            (
              helpers.meson {
                name = "fixture";
                inherit meson ninja pkg-config;
              }
            );
      };
    args = {
      base = tvp.bases.default;
      inherit (tvp.packages)
        bash
        coreutils
        meson
        ninja
        pkg-config
        ;
    };
    dependencyNames = [
      "bash"
      "coreutils"
      "meson"
      "ninja"
      "pkg-config"
    ];
    metadata.status.level = "ok";
    selection.kind = "fixture";
    mkTests = package: {
      run = package.stdenv.mkDerivation {
        name = "native-meson-customized-consumer";
        buildCommand = ''${package}/bin/probe; test -e ${package}/replacement; touch "$out"'';
      };
    };
  };
  insert = steps.insertAfter "fixture.build" [
    {
      name = "fixture.inserted";
      run = ''printf 'once\n' > "$out/inserted"'';
    }
  ];
  replace = steps.replace "fixture.inserted" (
    old:
    old
    // {
      run = ''test "$(cat "$out/inserted" 2>/dev/null || :)" = ""; mkdir -p "$out"; printf 'once\n' > "$out/replacement"'';
    }
  );
  disable = steps.replace "fixture.check" (
    old:
    old
    // {
      enabled = false;
      run = throw "disabled Meson check run";
      tools = throw "disabled Meson check tools";
    }
  );
  edits = value: ((value.editSteps insert).editSteps replace).editSteps disable;
  reboundMeson = tvp.packages.meson.override { inherit ninja pkg-config; };
  selected = (edits fixture).override {
    inherit ninja pkg-config;
    meson = reboundMeson;
  };
  alternate = edits (
    fixture.override {
      inherit ninja pkg-config;
      meson = reboundMeson;
    }
  );
  traced = selected.editSteps (
    steps.append [
      {
        name = "fixture.verify";
        run = ''
          test "$(cat "$out/replacement")" = once
          test ! -e "$out/inserted"
          grep -Fx ninja "$NIX_BUILD_TOP/tool-invocations"
          grep -Fx pkg-config "$NIX_BUILD_TOP/tool-invocations"
          cp "$NIX_BUILD_TOP/tool-invocations" "$out/tool-invocations"
        '';
      }
    ]
  );
  customized = p.override {
    inherit ninja pkg-config;
    meson = reboundMeson;
    doCheck = false;
  };
  # Construction and finalization have separate workspaces. Verify the selected
  # tools in A and carry only the resulting trace through the normal payload copy.
  tracedFontconfig = customized.editSteps (
    steps.insertBefore "fontconfig.finalize" [
      {
        name = "fontconfig.verify-invocations";
        run = ''
          grep -Fx ninja "$NIX_BUILD_TOP/tool-invocations"
          grep -Fx pkg-config "$NIX_BUILD_TOP/tool-invocations"
          cp "$NIX_BUILD_TOP/tool-invocations" "$out/tool-invocations"
        '';
      }
    ]
  );
  contracts = {
    replay = selected.drvPath == alternate.drvPath;
    noOpHelperOverride = (fixture.override { }).drvPath == fixture.drvPath;
    defaultCheckEnabled = (builtins.elemAt (steps.active fixture.buildSteps) 3).name == "fixture.check";
    disabledCheckLazy =
      !(builtins.any (s: s.name == "fixture.check") (steps.active selected.buildSteps));
    selectedNinja =
      (builtins.elemAt (steps.active selected.buildSteps) 1).env.NINJA == "${ninja}/bin/ninja";
    selectedPkgConfig =
      (builtins.elemAt (steps.active selected.buildSteps) 1).env.PKG_CONFIG
      == "${pkg-config}/bin/pkg-config";
    sourceRetained = customized.src == p.src;
    metadataCurrent =
      customized.tvp.deps.ninja == ninja && customized.tvp.declaredDependencies.pkg-config == pkg-config;
    featuresCurrent = !customized.tvp.features.doCheck && customized.tvp.features.tests;
    independentUpstream =
      p.tests.upstream.passthru.raw != null
      && customized.tests.upstream.passthru.raw == null
      && builtins.isString customized.tests.upstream.drvPath;
    checkGuardReusesProduction =
      (p.override { doCheck = false; }).artifact.drvPath == p.artifact.drvPath
      && (p.override { doCheck = false; }).drvPath == p.drvPath;
    noProductionCheck = !(builtins.any (s: s.name == "fontconfig.check") customized.buildSteps);
    traceBeforeSplit =
      builtins.any (
        s: s.name == "fontconfig.verify-invocations"
      ) (steps.partition tracedFontconfig.buildSteps).first
      && !(builtins.any (
        s: s.name == "fontconfig.verify-invocations"
      ) (steps.partition tracedFontconfig.buildSteps).second);
    customizedSelection = customized.__tvpSelection.kind == "override";
    testsRebound =
      customized.tests.consumer.drvPath != p.tests.consumer.drvPath
      && customized.tests.consumer.package.outPath == customized.outPath;
    lazyCustomizedTests = builtins.all (test: builtins.isString test.drvPath) (
      builtins.attrValues customized.tests
    );
  };
  failed = builtins.filter (n: !contracts.${n}) (builtins.attrNames contracts);
in
assert failed == [ ] || throw "Native Meson contracts: ${lib.concatStringsSep ", " failed}";
(tvp.bases.default.stdenv.mkDerivation {
  name = "tvp-native-meson-contracts";
  buildCommand = ''
    test -x ${fixture}/bin/probe
    test -e ${traced.tests.run}
    test -e ${tracedFontconfig.tests.installed}
    test -e ${tracedFontconfig.tests.upstream}
    test -e ${tracedFontconfig}/tool-invocations
    cat ${traced}/tool-invocations
    printf '%s\n' '${builtins.toJSON contracts}' > "$out"
  '';
})
// {
  passthru = {
    inherit
      contracts
      traced
      customized
      tracedFontconfig
      ;
  };
}

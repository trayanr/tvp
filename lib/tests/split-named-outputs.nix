# Installed trees only: the generic transport does not relocate embedded prefixes.
{ pkgs, tvp }:
let
  inherit (pkgs) lib;
  inherit (tvp.builder) steps outputs;
  inherit (tvp.packages) bash coreutils;
  base = tvp.canonical.mpfr_4_2_2.specification.base.override { tools = [ coreutils ]; };
  primitive =
    name: body:
    builtins.derivation {
      inherit name;
      inherit (base.platform) system;
      builder = "${bash}/bin/bash";
      args = [
        "-euc"
        body
      ];
    };
  fixture =
    secondary:
    tvp.builder {
      recipe =
        {
          base,
          bash,
          coreutils,
          message,
        }:
        final: {
          pname = "split-named-${secondary}";
          version = "1";
          src = null;
          inherit base bash coreutils;
          outputs = [
            "out"
            secondary
          ];
          runtime.message = message;
          passthru = raw: {
            marker = "${raw.${secondary}}/marker";
            effectiveOutput = raw.${secondary};
          };
          plan = [
            {
              name = "fixture.install";
              run = ''
                test -z "''${TVP_ARTIFACT_ROOT-}''${TVP_ARTIFACT_OUTPUTS-}"
                mkdir -p "$out/nix-support" "${"$" + secondary}"
                printf '315532801\n' > "$out/nix-support/source-date-epoch"
                printf installed > "$out/installed"
                printf '${secondary}' > "${"$" + secondary}/kind"
                chmod 444 "${"$" + secondary}/kind"
                ln -s kind "${"$" + secondary}/relative"
                printf '%s' "$TMPDIR" > "$out/temporary"
              '';
            }
            (steps.split "fixture.finalize")
            (outputs.copyArtifacts {
              inherit coreutils;
              outputs = final.outputs;
            })
            {
              name = "fixture.finish";
              run = ''
                test "$TVP_ARTIFACT_ROOT" = "''${TVP_ARTIFACT_OUTPUTS[out]}"
                test ! -e "$(cat "$out/temporary")"
                test "$(cat source-date-epoch)" = 315532801
                test "$SOURCE_DATE_EPOCH" = 315532801
                test -w "${"$" + secondary}/kind"
                test "$(readlink "${"$" + secondary}/relative")" = kind
                test -z "''${LEAK-}''${NIX_ATTRS_SH_FILE-}''${outputs-}''${AMBIENT-}"
                printf '%s' ${lib.escapeShellArg final.runtime.message} > "$out/message"
                printf '%s' ${lib.escapeShellArg final.runtime.message} > "${"$" + secondary}/message"
              '';
            }
          ];
        };
      args = {
        inherit base bash coreutils;
        message = "first";
      };
      dependencyNames = [ ];
      metadata = { };
      selection.kind = "fixture";
      mkTests = p: {
        read = primitive "split-named-rebound" ''
          export PATH=${coreutils}/bin
          test "$(cat ${p.${secondary}}/message)" = ${lib.escapeShellArg p.runtime.message}
          printf '%s' '${p.${secondary}}' > "$out"
        '';
      };
    };
  fixtures = lib.genAttrs [
    "evidence"
    "validation"
    "bin"
  ] fixture;
  changed = lib.mapAttrs (
    _: p:
    p.editRuntime (_: {
      message = "second";
    })
  ) fixtures;
  stepChanged = lib.mapAttrs (
    _: p:
    p.editSteps (
      steps.append [
        {
          name = "fixture.extra";
          run = ''printf extra > "$out/extra"'';
        }
      ]
    )
  ) fixtures;
  prefixChanged = lib.mapAttrs (
    _: p:
    p.editSteps (
      steps.replace "fixture.install" (
        s:
        s
        // {
          run = s.run + ''printf changed > "$out/changed"'';
        }
      )
    )
  ) fixtures;
  policy = tvp.lib.recipeSplits;
  row = p: builtins.head (policy.inventory { canonical.fixture_1 = p; }).rows;
  invalid = p: (row p).failure == "invalid-artifact-producer";
  p = fixtures.evidence;
  rejects = v: !(builtins.tryEval (builtins.deepSeq v true)).success;
  append =
    p: run:
    p.editSteps (
      steps.append [
        {
          name = "negative.run";
          inherit run;
        }
      ]
    );
  same =
    a: b: a.outPath == b.outPath && builtins.getContext a.outPath == builtins.getContext b.outPath;
  contracts = {
    admitted = builtins.all (x: (row x).compliant) (builtins.attrValues fixtures);
    exactlyTwoProducers = builtins.all (
      x:
      x.outputs == x.artifact.outputs
      && x.drvPath != x.artifact.drvPath
      && builtins.all (
        n: x.${n}.drvPath == x.drvPath && x.artifact.${n}.drvPath == x.artifact.drvPath
      ) x.outputs
    ) (builtins.attrValues fixtures);
    runtimePreservesAllArtifactOutputs = builtins.all (
      n:
      fixtures.${n}.drvPath != changed.${n}.drvPath
      && builtins.all (
        o: same fixtures.${n}.artifact.${o} changed.${n}.artifact.${o}
      ) fixtures.${n}.outputs
    ) (builtins.attrNames fixtures);
    suffixPreservesAllArtifactOutputs = builtins.all (
      n:
      fixtures.${n}.drvPath != stepChanged.${n}.drvPath
      && builtins.all (
        o: same fixtures.${n}.artifact.${o} stepChanged.${n}.artifact.${o}
      ) fixtures.${n}.outputs
    ) (builtins.attrNames fixtures);
    prefixChangesBothProducers = builtins.all (
      n:
      fixtures.${n}.drvPath != prefixChanged.${n}.drvPath
      && builtins.all (
        o: fixtures.${n}.artifact.${o}.outPath != prefixChanged.${n}.artifact.${o}.outPath
      ) fixtures.${n}.outputs
    ) (builtins.attrNames fixtures);
    allProjections = builtins.all (
      n:
      let
        x = fixtures.${n};
        c = changed.${n};
        selected = x.${n}.editRuntime (_: {
          message = "second";
        });
      in
      same x.out x
      && x.${n}.outputName == n
      && same selected c.${n}
      && selected.outputName == n
      && selected.out.drvPath == c.drvPath
      && same (builtins.elemAt x.all 0) x.out
      && same (builtins.elemAt x.all 1) x.${n}
      && (builtins.elemAt x.all 1).outputName == n
      &&
        (builtins.getContext x.${n}.outPath).${builtins.unsafeDiscardStringContext x.drvPath}.outputs
        == [ n ]
      && selected.tests.read.drvPath == c.tests.read.drvPath
      && selected.tests.read.drvPath != x.tests.read.drvPath
      && selected.marker == "${selected}/marker"
      && same selected.effectiveOutput selected
    ) (builtins.attrNames fixtures);
    forgedSecondary = invalid (p // { evidence = fixtures.validation.validation; });
    forgedArtifactSecondary = invalid (
      p
      // {
        artifact = p.artifact // {
          evidence = fixtures.validation.artifact.validation;
        };
      }
    );
    missingSecondary = invalid (removeAttrs p [ "evidence" ]);
    missingArtifactSecondary = invalid (p // { artifact = removeAttrs p.artifact [ "evidence" ]; });
    wrongOutputSet = invalid (p // { outputs = [ "out" ]; });
    forgedProjectionArtifact = invalid (
      p
      // {
        evidence = p.evidence // {
          artifact = prefixChanged.evidence.artifact;
        };
      }
    );
    forgedAll = invalid (
      p
      // {
        all = [
          p.out
          fixtures.validation.validation
        ];
      }
    );
    wrongSecondaryContext = invalid (
      p
      // {
        evidence = p.evidence // {
          outPath = builtins.unsafeDiscardStringContext p.evidence.outPath;
        };
      }
    );
    wrongArtifactContext = invalid (
      p
      // {
        artifact = p.artifact // {
          evidence = p.artifact.evidence // {
            outPath = builtins.unsafeDiscardStringContext p.artifact.evidence.outPath;
          };
        };
      }
    );
    wrongArtifactOutputProducer = invalid (
      p
      // {
        artifact = p.artifact // {
          evidence = p.artifact.evidence // {
            drvPath = prefixChanged.evidence.artifact.drvPath;
          };
        };
      }
    );
    wrongSecondaryProducer = invalid (
      p
      // {
        evidence = p.evidence // {
          drvPath = changed.evidence.drvPath;
        };
      }
    );
    environmentSpoofing =
      builtins.all
        (
          key:
          rejects
            (p.editSteps (
              steps.append [
                {
                  name = "negative.env";
                  env.${key} = "spoof";
                  run = ":";
                }
              ]
            )).drvPath
        )
        [
          "out"
          "evidence"
          "TVP_ARTIFACT_ROOT"
          "TVP_ARTIFACT_OUTPUTS"
        ];
    outputChecksPreserved =
      let
        x = p.edit (
          s:
          s
          // {
            outputChecks = {
              out = {
                maxSize = 100000;
                disallowedReferences = [ bash ];
              };
              evidence.maxClosureSize = 1000000000;
            };
          }
        );
      in
      x.outputChecks.out.maxSize == 100000
      && x.outputChecks.evidence.maxClosureSize == 1000000000
      &&
        map toString x.outputChecks.out.disallowedReferences == map toString [
          bash
          x.artifact.out
          x.artifact.evidence
        ]
      &&
        map toString x.outputChecks.evidence.disallowedReferences == map toString [
          x.artifact.out
          x.artifact.evidence
        ];
    finalChecksPreserveArtifact =
      (p.edit (s: s // { outputChecks.evidence.maxSize = 100000; })).artifact.drvPath
      == p.artifact.drvPath;
    invalidCopyNames =
      rejects
        (outputs.copyArtifacts {
          inherit coreutils;
          outputs = [ "evidence" ];
        }).run;
  };
  # All directed pairs, for each public output shape. Nix checks arbitrary bytes
  # and symlink targets; no recipe-level text scan stands in for the native check.
  leaks = builtins.listToAttrs (
    lib.concatMap (
      secondary:
      lib.concatMap
        (
          destination:
          lib.concatMap
            (
              source:
              map
                (kind: {
                  name = "${secondary}-${destination}-${source}-${kind}";
                  value = append fixtures.${secondary} (
                    if kind == "bytes" then
                      ''printf '\000%s\377' "''${TVP_ARTIFACT_OUTPUTS[${source}]}" > "${"$" + destination}/leak"''
                    else
                      ''ln -s "''${TVP_ARTIFACT_OUTPUTS[${source}]}/kind" "${"$" + destination}/leak"''
                  );
                })
                [
                  "bytes"
                  "symlink"
                ]
            )
            [
              "out"
              secondary
            ]
        )
        [
          "out"
          secondary
        ]
    ) (builtins.attrNames fixtures)
  );
  elfLeaks = builtins.listToAttrs (
    lib.concatMap
      (
        destination:
        map
          (source: {
            name = "elf-${destination}-${source}";
            value = p.editSteps (
              steps.append [
                (
                  (base.environment { })
                  // {
                    name = "negative.elf";
                    run = ''
                      printf 'const char *prefix = "%s"; int main(void) { return prefix[0] != 47; }\n' \
                        "''${TVP_ARTIFACT_OUTPUTS[${source}]}" > leak.c
                      "$CC" leak.c -o "${"$" + destination}/leak-elf"
                    '';
                  }
                )
              ]
            );
          })
          [
            "out"
            "evidence"
          ]
      )
      [
        "out"
        "evidence"
      ]
  );
  failures = {
    callerPrimaryCheck = p.edit (s: s // { outputChecks.out.maxSize = 1; });
    callerSecondaryCheck = p.edit (s: s // { outputChecks.evidence.maxSize = 1; });
    missingArtifact = p.editSteps (
      steps.replace "fixture.install" (s: s // { run = ''mkdir -p "$out"''; })
    );
    missingFinal = p.editSteps (_: [
      (builtins.head p.buildSteps)
      (steps.split "fixture.split")
      {
        name = "fixture.omit";
        run = ''mkdir -p "$out"'';
      }
    ]);
    malformedArtifact = p.editSteps (
      steps.replace "fixture.install" (s: s // { run = ''mkdir -p "$out"; touch "$evidence"''; })
    );
    wrongMapping = p.editSteps (
      steps.replace "output.copy-artifacts" (
        _:
        outputs.copyArtifacts {
          inherit coreutils;
          outputs = [
            "out"
            "validation"
          ];
        }
      )
    );
    incompleteMapping = p.editSteps (
      steps.replace "output.copy-artifacts" (
        _:
        outputs.copyArtifacts {
          inherit coreutils;
          outputs = [ "out" ];
        }
      )
    );
    missingMapping = p.editSteps (_: [
      (outputs.copyArtifacts {
        inherit coreutils;
        outputs = [
          "out"
          "evidence"
        ];
      })
    ]);
    readonlyPrimary = append p ''out=spoof; touch "$TVP_SOURCE_ROOT/unreachable"'';
    readonlySecondary = append p ''evidence=spoof; touch "$TVP_SOURCE_ROOT/unreachable"'';
    readonlyMap = append p ''TVP_ARTIFACT_OUTPUTS[evidence]=spoof; touch "$TVP_SOURCE_ROOT/unreachable"'';
    readonlyRoot = append p ''TVP_ARTIFACT_ROOT=spoof; touch "$TVP_SOURCE_ROOT/unreachable"'';
    suffixFailure = p.editSteps (
      steps.insertBefore "output.copy-artifacts" [
        {
          name = "negative.stop";
          run = "exit 37";
        }
      ]
    );
  };
  failed = builtins.filter (n: !contracts.${n}) (builtins.attrNames contracts);
  check = primitive "tvp-split-named-output-contracts" ''
    export PATH=${coreutils}/bin
    ${lib.concatMapStringsSep "\n" (n: ''
      test "$(cat ${fixtures.${n}}/installed)" = installed
      test "$(cat ${fixtures.${n}.${n}}/kind)" = '${n}'
      test "$(cat ${fixtures.${n}.${n}}/message)" = first
      test "$(cat ${changed.${n}.${n}}/message)" = second
      test "$(cat ${prefixChanged.${n}}/changed)" = changed
      test "$(cat ${stepChanged.${n}}/extra)" = extra
      test "$(cat ${changed.${n}.tests.read})" = '${changed.${n}.${n}}'
      test "$(stat -c %a ${fixtures.${n}.artifact.${n}}/kind)" = 444
      test "$(readlink ${fixtures.${n}.${n}}/relative)" = kind
    '') (builtins.attrNames fixtures)}
    printf '%s\n' '${builtins.toJSON contracts}' > "$out"
  '';
in
assert failed == [ ] || throw "Split named-output contracts: ${lib.concatStringsSep ", " failed}";
check
// {
  passthru = {
    inherit
      contracts
      fixtures
      changed
      stepChanged
      prefixChanged
      failures
      elfLeaks
      leaks
      ;
  };
}

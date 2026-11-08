{ pkgs, tvp }:
let
  inherit (pkgs) lib;
  base = tvp.bases.default;
  inherit (tvp.packages) bash coreutils;
  inherit (tvp.builder) steps;
  primitive =
    name: body:
    builtins.derivation {
      inherit name;
      outputs = [ "out" ];
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
          pname = "named-${secondary}";
          version = "1";
          src = null;
          inherit base bash coreutils;
          outputs = [
            "out"
            secondary
          ];
          passthru.factory = value: (fixture secondary).override { message = value; };
          runtime.message = message;
          plan = [
            {
              name = "fixture.write";
              run = ''
                test -z "''${NIX_ATTRS_SH_FILE-}''${NIX_ATTRS_JSON_FILE-}''${AMBIENT-}''${outputs-}"
                test "$out" != "${"$" + secondary}"
                mkdir -p "$out" "${"$" + secondary}"
                printf '%s' ${lib.escapeShellArg final.runtime.message} > "$out/message"
                printf '%s' '${secondary}' > "${"$" + secondary}/kind"
                printf '%s' "${"$" + secondary}" > "$out/secondary"
                ${lib.optionalString (secondary == "bin") ''
                  mkdir -p "$bin/bin"
                  printf '#!${bash}/bin/bash\ncat %s/read\n' "$bin" > "$bin/bin/named-tool"
                  chmod +x "$bin/bin/named-tool"
                ''}
                printf '%s' "$TMPDIR" > temporary
                export LEAK=forbidden
                mkdir -p "$TMPDIR/child"
              '';
            }
            {
              name = "fixture.read";
              run = ''
                test -z "''${LEAK-}''${AMBIENT-}''${NIX_ATTRS_SH_FILE-}''${NIX_ATTRS_JSON_FILE-}"
                test "$(cat "$out/message")" = ${lib.escapeShellArg final.runtime.message}
                test "$(cat "${"$" + secondary}/kind")" = '${secondary}'
                test "$(cat "$out/secondary")" = "${"$" + secondary}"
                test "$TMPDIR" != "$(cat temporary)"
                test ! -e "$(cat temporary)"
                printf '%s' ${lib.escapeShellArg final.runtime.message} > "${"$" + secondary}/read"
              '';
            }
            {
              name = "fixture.disabled";
              enabled = false;
              env.${secondary} = throw "disabled output override";
              run = throw "disabled body";
              tools = throw "disabled tools";
            }
          ];
        };
      args = {
        inherit base bash coreutils;
        message = "first";
      };
      dependencyNames = [ ];
      metadata.definition = "named-output-fixture";
      selection.kind = "fixture";
      mkTests = package: {
        read = primitive "named-output-rebound-test" ''
          export PATH=${coreutils}/bin
          test "$(cat ${
            package.validation or package.bin
          }/read)" = ${lib.escapeShellArg package.runtime.message}
          printf '%s' '${package.validation or package.bin}' > "$out"
        '';
      };
    };
  validation = fixture "validation";
  binary = fixture "bin";
  edit = package: package.editRuntime (r: r // { message = r.message + "-edited"; });
  changed = (edit validation.validation).override { message = "second"; };
  binChanged = (edit binary.bin).override (args: {
    message = args.message + "-second";
  });
  rejects = value: !(builtins.tryEval (builtins.deepSeq value true)).success;
  badNames = names: rejects (validation.edit (s: s // { outputs = names; })).drvPath;
  envSpoof =
    key:
    rejects
      (validation.editSteps (
        steps.append [
          {
            name = "fixture.spoof";
            env.${key} = "forbidden";
            run = ":";
          }
        ]
      )).drvPath;
  # A direct output-body assignment must fail inside a fresh step too.
  readonlyFailure = binary.editSteps (_: [
    {
      name = "fixture.mutate";
      run = "bin=spoofed; echo unreachable";
    }
    {
      name = "fixture.forbidden";
      run = "touch forbidden";
    }
  ]);
  attrset = validation.edit (
    s:
    s
    // {
      development = {
        marker = "attrset";
        libraries = [ binary ];
      };
    }
  );
  functional = validation.edit (
    s:
    s
    // {
      development = raw: {
        marker = "function";
        rawIsUndecorated = !(raw ? development) && !(raw ? edit) && !(raw ? tvp);
        aclocalDirectories = [
          "${raw}/first"
          "${raw}/second"
        ];
      };
    }
  );
  metadataChanged = functional.editSteps (_: [
    {
      name = "metadata.changed";
      run = ":";
    }
  ]);
  multi = functional.edit (
    s:
    s
    // {
      plan = [
        {
          name = "metadata.exports";
          run = ":";
          developmentLibraries = [
            binary
            binary
          ];
        }
      ];
      development = raw: {
        aclocalDirectories = [ "${raw.validation}/macros" ];
        libraries = [ validation ];
      };
    }
  );
  multiChanged = multi.validation.editSteps (_: [
    {
      name = "metadata.second";
      run = ": second";
      developmentLibraries = [ binary ];
    }
  ]);
  metadataRebound = functional.override { message = "metadata-rebound"; };
  contracts = {
    developmentDefault = validation.development.libraries == [ ];
    attrsetDerivationUnchanged = attrset.drvPath == validation.drvPath;
    attrsetFieldsUnchanged = attrset.development.marker == "attrset";
    attrsetExportsPreservePrecedence = attrset.development.libraries == [ ];
    callbackNoProcedureChange = functional.drvPath == validation.drvPath;
    callbackRawOutputOnly = functional.development.rawIsUndecorated;
    callbackTwoDirectories =
      functional.development.aclocalDirectories == [
        "${functional}/first"
        "${functional}/second"
      ];
    editsRefreshMetadata =
      metadataChanged.outPath != functional.outPath
      &&
        metadataChanged.development.aclocalDirectories == [
          "${metadataChanged}/first"
          "${metadataChanged}/second"
        ];
    overrideRefreshesMetadata =
      metadataRebound.outPath != functional.outPath
      &&
        metadataRebound.development.aclocalDirectories == [
          "${metadataRebound}/first"
          "${metadataRebound}/second"
        ];
    namedMetadataLookup = multi.development.aclocalDirectories == [ "${multi.validation}/macros" ];
    namedProjectionMetadata =
      multi.validation.development.aclocalDirectories == multi.development.aclocalDirectories;
    selectedOutputMetadataEdit =
      multiChanged.outputName == "validation"
      && multiChanged.outPath != multi.validation.outPath
      && multiChanged.development.aclocalDirectories == [ "${multiChanged}/macros" ];
    exportsMergeDeduplicate = multi.development.libraries == [ binary ];
    callbackStringContext =
      (builtins.getContext (builtins.head multi.development.aclocalDirectories))
      .${builtins.unsafeDiscardStringContext multi.drvPath}.outputs == [ "validation" ];

    separate =
      validation.outPath != validation.validation.outPath && binary.outPath != binary.bin.outPath;
    getOutput = (lib.getOutput "validation" validation).outPath == validation.validation.outPath;
    getBin = (lib.getBin binary).outPath == binary.bin.outPath;
    projection = changed.outputName == "validation" && binChanged.outputName == "bin";
    replay = changed.outPath == ((edit validation).override { message = "second"; }).validation.outPath;
    editProjection =
      (validation.validation.edit (s: s)).outputName == "validation"
      && (binary.bin.editSteps (plan: plan)).outPath == binary.bin.outPath;
    taggedProjection =
      ((tvp.lib.packages.tagSelection { kind = "fixture"; } binary).bin.override { message = "tagged"; })
      .outputName == "bin";
    outProjection = changed.out.outputName == "out" && changed.out.outPath != changed.outPath;
    allProjection =
      map (p: p.outPath) changed.all == [
        changed.out.outPath
        changed.outPath
      ];
    projectionOutputs =
      changed.outputs == validation.outputs && builtins.all (p: p.outputs == binary.outputs) binary.all;
    recursiveProjection = (builtins.head changed.all).validation.outPath == changed.outPath;
    reboundTests =
      changed.tests.read.drvPath != validation.tests.read.drvPath
      && changed.tests.read.drvPath == changed.out.tests.read.drvPath
      && changed.passthru.tests.read.drvPath == changed.tests.read.drvPath;
    provenance =
      changed.tvp.customization.customized
      && changed.tvp.customization.edits == 1
      && changed.out.tvp == changed.tvp
      && changed.tvp.definition == "named-output-fixture";
    passthru = (binary.bin.factory "factory").runtime.message == "factory";
    context =
      (builtins.getContext "${changed}").${builtins.unsafeDiscardStringContext changed.drvPath}.outputs
      == [ "validation" ];
    noRawAttrs = !(changed ? overrideAttrs);
    explicitDefault =
      (validation.edit (s: s // { outputs = [ "out" ]; })).drvPath
      == (validation.edit (s: removeAttrs s [ "outputs" ])).drvPath;
    invalid =
      builtins.all
        (
          name:
          badNames [
            "out"
            name
          ]
        )
        [
          "script"
          "status"
          "temporary"
          "bad-name"
          "bad\nname"
          "x;touch injected"
          ""
          1
          "${binary}"
          "PATH"
          "BASH_ENV"
          "NIX_ATTRS_SH_FILE"
          "outputs"
          "all"
          "tests"
          "passthru"
          "builder"
          "system"
          "meta"
          "runtime"
          "buildStepRunner"
          "specification"
          "override"
          "env"
          "histchars"
          "auto_resume"
        ]
      && builtins.all badNames [
        [ ]
        [ "validation" ]
        [
          "validation"
          "out"
        ]
        [
          "out"
          "out"
        ]
        "out"
      ];
    passthruCollision =
      rejects
        (validation.edit (s: s // { passthru.validation = "collision"; })).drvPath;
    envIsolation = builtins.all envSpoof [
      "out"
      "validation"
      "NIX_ATTRS_SH_FILE"
      "BASH_ENV"
      "outputs"
    ];
    binEnvIsolation =
      rejects
        (binary.editSteps (
          steps.append [
            {
              name = "fixture.spoof";
              env.bin = "bad";
              run = ":";
            }
          ]
        )).drvPath;
    splitRejected =
      rejects
        (validation.editSteps (steps.insertAfter "fixture.write" [ (steps.split "fixture.split") ]))
        .drvPath;
    invalidBeforePayload =
      !(builtins.tryEval (
        builtins.seq (validation.edit (
          s:
          s
          // {
            outputs = [
              "out"
              "tests"
            ];
            plan = throw "must not force plan";
          }
        )).drvPath true
      )).success;
  };
  failed = builtins.filter (n: !contracts.${n}) (builtins.attrNames contracts);
in
assert failed == [ ] || throw "Named output contracts: ${lib.concatStringsSep ", " failed}";
(primitive "tvp-named-output-contracts" ''
  export PATH=${coreutils}/bin
  test "$(cat ${validation}/message)" = first
  test "$(cat ${validation.validation}/kind)" = validation
  test "$(cat ${validation.validation}/read)" = first
  test "$(cat ${binary.bin}/kind)" = bin
  test "$(${lib.getBin binary}/bin/named-tool)" = first
  test "$(cat ${binary.bin}/read)" = first
  test "$(cat ${changed}/read)" = second-edited
  test "$(cat ${binChanged}/read)" = first-second-edited
  test "$(cat ${changed.tests.read})" = '${changed}'
  test "$(cat ${binary.tests.read})" = '${binary.bin}'
  mkdir failure
  cd failure
  if env -i AMBIENT=must-not-leak out="$PWD/out" bin="$PWD/bin" \
    ${bash}/bin/bash ${readonlyFailure.buildStepRunner.script} "$PWD" > log 2>&1; then
    echo 'output reassignment succeeded' >&2; exit 1
  fi
  [[ $(<log) == *'readonly variable'* ]]
  [[ $(<log) == *'"event":"failure"'* ]]
  test ! -e forbidden
  if env -i out="$PWD/out" ${bash}/bin/bash ${binary.buildStepRunner.script} "$PWD" > missing 2>&1; then
    echo 'missing secondary output succeeded' >&2; exit 1
  fi
  [[ $(<missing) == *'missing output bin'* ]]
  cd ..
  mkdir isolated
  env -i AMBIENT=must-not-leak NIX_ATTRS_SH_FILE=forbidden NIX_ATTRS_JSON_FILE=forbidden \
    out="$PWD/isolated-out" validation="$PWD/isolated-validation" \
    ${bash}/bin/bash ${validation.buildStepRunner.script} "$PWD/isolated"
  test "$(cat isolated-validation/read)" = first
  printf '%s\n' '${builtins.toJSON contracts}' > "$out"
'')
// {
  passthru = {
    inherit
      contracts
      validation
      binary
      changed
      binChanged
      ;
  };
}

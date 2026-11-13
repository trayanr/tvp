{ pkgs, tvp }:
let
  inherit (pkgs) lib;
  steps = import ../build-steps.nix;
  p = import ./fixtures/mpfr.nix { inherit pkgs tvp; };
  gmp = tvp.packages.gmp_6_2_1;
  insert = steps.insertAfter "mpfr.build" [
    {
      name = "local.log";
      run = "echo built >&2";
    }
  ];
  disable = steps.replace "mpfr.save-build-tree" (
    old:
    old
    // {
      enabled = false;
      run = throw "disabled run";
      tools = throw "disabled tools";
    }
  );
  a = ((p.override { inherit gmp; }).editSteps insert).editSteps disable;
  b = ((p.editSteps insert).editSteps disable).override { inherit gmp; };
  rejects = x: !(builtins.tryEval (builtins.deepSeq x true)).success;
  otherBase = p.specification.base.override { name = "native-recipe-other-base"; };
  other = p.override { base = otherBase; };
  contracts = {
    overrideReplay = a.drvPath == b.drvPath;
    retainedArguments = a.version == p.version && a.src == p.src;
    editsAccumulate = builtins.length a.buildSteps == builtins.length p.buildSteps + 1;
    oneInsertion = builtins.length (builtins.filter (s: s.name == "local.log") a.buildSteps) == 1;
    unknown = rejects (p.override { typo = true; }).drvPath;
    missing = rejects (p.editSteps (steps.delete "missing.step")).drvPath;
    duplicate =
      rejects
        (p.editSteps (
          steps.append [
            {
              name = "mpfr.build";
              run = ":";
            }
          ]
        )).drvPath;
    noOpOverride = (p.override { }).drvPath == p.drvPath;
    noOpEdit = (p.editSteps (plan: plan)).drvPath == p.drvPath;
    baseCoherence =
      other.specification.base.name == otherBase.name
      && other.compiler.drvPath == otherBase.compiler.drvPath
      && other.tvp.cc.drvPath == otherBase.compiler.drvPath
      && !(other ? stdenv);
    dependencies =
      a.tvp.declaredDependencies.gmp.outPath == gmp.outPath && a.tvp.deps.gmp.outPath == gmp.outPath;
    selection = a.__tvpSelection.kind == "override" && a.out.__tvpSelection.kind == "override";
    metadataProjection = a.out.tvp.declaredDependencies.gmp.outPath == gmp.outPath;
    argumentOnlyDependencyFallback = composed.tvp.deps.gmp.outPath == gmp.outPath;
    testsRebound =
      a.tests.version.drvPath != p.tests.version.drvPath
      && a.tests.version.package.outPath == a.outPath
      && a.tests.version.specification.base.compiler.drvPath == a.compiler.drvPath;
    lazyTests = builtins.all (test: builtins.isString test.drvPath) (builtins.attrValues a.tests);
  };
  # A small real recipe exercises the same seam without rebuilding MPFR merely
  # to observe chaining. Its installed executable really links selected GMP.
  fixture = import ../native-recipe.nix { inherit lib; } {
    recipe =
      {
        base,
        bash,
        coreutils,
        gmp,
        src,
        version,
      }:
      {
        pname = "native-recipe-fixture";
        inherit
          base
          bash
          coreutils
          src
          version
          ;
        runtime.libraries = [ (lib.getLib gmp) ];
        plan = [
          {
            name = "fixture.build";
            libraries = [ gmp ];
            run = ''
              mkdir -p "$out/bin"
              printf '#include <gmp.h>\n#include <stdio.h>\nint main(void) { puts(gmp_version); }\n' > main.c
              "$CC" main.c -lgmp -o "$out/bin/version"
            '';
          }
        ];
      };
    args = {
      base = tvp.bases.default;
      inherit (tvp.packages) bash coreutils;
      gmp = tvp.packages.gmp_6;
      src = p.src;
      version = "1";
    };
    dependencyNames = [
      "gmp"
      "bash"
      "coreutils"
    ];
    metadata.status.level = "ok";
    selection.kind = "fixture";
    mkTests = package: {
      run = package.stdenv.mkDerivation {
        name = "native-customized-consumer";
        buildCommand = ''${package}/bin/version > "$out"; grep -Fx ${lib.escapeShellArg package.tvp.deps.gmp.version} "$out"'';
      };
    };
  };
  composed =
    (
      (fixture.editSteps (
        steps.insertAfter "fixture.build" [
          {
            name = "fixture.log";
            run = ''printf 'once\n' > "$out/log"'';
          }
        ]
      )).editSteps
      (
        steps.replace "fixture.log" (
          old:
          old
          // {
            run = old.run + ''; test "$(wc -l < "$out/log")" = 1'';
          }
        )
      )
    ).override
      { inherit gmp; };
  runtime = import ../runtime-expectation.nix { inherit lib; } {
    package = composed;
    stdenv = composed.stdenv;
    python = tvp.packages.python_3;
  };
  absent = runtime.overrideAttrs (old: {
    name = "native-runtime-absent-control";
    expectedLibraries = [ (builtins.unsafeDiscardStringContext tvp.packages.zlib.outPath) ];
    installPhase = ''
      if ( ${old.installPhase} ) 2> rejected.log; then
        echo 'absent library incorrectly accepted' >&2; exit 1
      fi
      grep -F "Runtime libraries absent from package closure:" rejected.log
      touch "$out"
    '';
  });
  auditRunner =
    import ../build-step-runner.nix
      {
        inherit lib;
        base = tvp.bases.default;
        inherit (tvp.packages) bash coreutils;
      }
      {
        temporaryDirectories = true;
        plan = [
          {
            name = "fixture.wrapper";
            run = ''
              mkdir -p "$out/bin"
              printf '#!${tvp.packages.bash}/bin/bash\necho %s\n' "$NIX_BUILD_TOP/earlier-step" > "$out/bin/tool"
              chmod +x "$out/bin/tool"
              touch "$out/bin/.tool-wrapped"
            '';
          }
        ] ++ (import ../native-steps.nix { inherit lib; }).finalize { };
      };
  auditControl = tvp.bases.default.stdenv.mkDerivation {
    name = "native-shared-build-path-audit-control";
    buildCommand = ''
      mkdir workspace
      if ${tvp.packages.bash}/bin/bash ${auditRunner.script} "$PWD/workspace" > audit.log 2>&1; then
        echo 'shared build path incorrectly accepted' >&2; exit 1
      fi
      grep -F 'contains a forbidden reference to' audit.log
      rm "$out/bin/tool" "$out/bin/.tool-wrapped"
      touch "$out/passed"
    '';
  };
  epochProbe =
    mode:
    fixture.editSteps (_: [
      {
        name = "epoch.prepare";
        run =
          ''
            mkdir -p "$out"
          ''
          + lib.optionalString (mode == "valid") ''
            printf '%s\n' 1700000000 > source-date-epoch
          ''
          + lib.optionalString (mode == "invalid") ''
            mkdir source-date-epoch
          '';
      }
      {
        name = "epoch.read";
        run = ''printf '%s\n' "''${SOURCE_DATE_EPOCH-unset}" > "$out/observed"'';
      }
    ]);
  epochControl = tvp.bases.default.stdenv.mkDerivation {
    name = "native-source-epoch-control";
    buildCommand = ''
      mkdir missing-work valid-work invalid-work
      out="$PWD/missing-out" ${tvp.packages.bash}/bin/bash ${(epochProbe "missing").buildStepRunner.script} "$PWD/missing-work"
      test "$(cat missing-out/observed)" = 315532800
      out="$PWD/valid-out" ${tvp.packages.bash}/bin/bash ${(epochProbe "valid").buildStepRunner.script} "$PWD/valid-work"
      test "$(cat valid-out/observed)" = 1700000000
      if out="$PWD/invalid-out" ${tvp.packages.bash}/bin/bash ${(epochProbe "invalid").buildStepRunner.script} "$PWD/invalid-work" > invalid.log 2>&1; then
        echo 'unreadable source epoch incorrectly accepted' >&2; exit 1
      else
        test "$?" = 1
      fi
      grep -F 'Is a directory' invalid.log
      test ! -e invalid-out/observed
      touch "$out"
    '';
  };
  failed = builtins.filter (n: !contracts.${n}) (builtins.attrNames contracts);
in
assert failed == [ ] || throw "Native recipe contracts: ${lib.concatStringsSep ", " failed}";
(tvp.bases.default.stdenv.mkDerivation {
  name = "tvp-native-recipe-contracts";
  buildCommand = ''
    test -e ${composed.tests.run}
    test -e ${runtime}
    test -e ${absent}
    test -e ${auditControl}
    test -e ${epochControl}
    printf '%s\n' '${builtins.toJSON contracts}' > "$out"
  '';
})
// {
  passthru = {
    inherit
      contracts
      composed
      runtime
      absent
      ;
  };
}

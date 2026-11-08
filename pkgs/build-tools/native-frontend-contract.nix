# Common constructor controls for the four native frontend suites. These probes
# replace compilation with a small real consumer; ordinary upstream/installed
# behavior is exercised by each family's own suite.
{
  pkgs,
  tvp,
  package,
}:
let
  inherit (pkgs) lib;
  inherit (tvp.builder) steps;
  p = package;
  sentinel = (import ../../bases/source-gnu/tests/probes.nix { }).sentinel;
  alternate = (import ../../bootstrap/source-cmake-prerequisite-tests.nix { }).alternate;
  altered = p.editSteps (
    steps.append [
      {
        name = "frontend.marker";
        run = ''printf selected > "$out/frontend-marker"'';
      }
    ]
  );
  rejects = value: !(builtins.tryEval (builtins.deepSeq value true)).success;
  first = builtins.head p.buildSteps;
  probe =
    ((p.override { src = "${alternate}/source.tar.gz"; }).edit (
      s:
      s
      // {
        base = s.base.override { compiler = sentinel; };
        environment = s.environment // {
          overrides.values.FRONTEND_CONTRACT = "explicit";
        };
      }
    )).edit
      (
        s:
        s
        // {
          plan = [
            (builtins.head s.plan)
            (
              (s.base.environment s.environment)
              // {
                name = "frontend.source-base-environment";
                run = ''
                  test "$(cat source/marker)" = 'alternate source'
                  test "$FRONTEND_CONTRACT" = explicit
                  printf 'int main(void) { return 0; }\n' > probe.c
                  "$CC" probe.c -o probe
                  "$CXX" -x c++ probe.c -o probe-cxx
                  env -i ./probe
                  env -i ./probe-cxx
                  test "$(cat selected-compiler)" = $'selected\nselected'
                  mkdir "$out"
                  cp source/marker selected-compiler "$out/"
                '';
              }
            )
          ];
        }
      );
  command = builtins.head (builtins.filter (s: s ? env && s.env ? CC) p.buildSteps);
  withEnvironment = p.edit (
    s:
    s
    // {
      environment = s.environment // {
        overrides.values.FRONTEND_CONTRACT = "current";
      };
    }
  );
  withBase = p.edit (s: s // { base = s.base.override { compiler = sentinel; }; });
  selectedCommand = q: builtins.head (builtins.filter (s: s.name == command.name) q.buildSteps);
  inserted = steps.insertAfter first.name [
    {
      name = "frontend.inserted";
      run = ":";
    }
  ];
  ordered = (p.editSteps inserted).editRuntime (r: r);
  contracts = {
    noOp =
      (p.override { }).drvPath == p.drvPath
      && (p.editSteps (x: x)).drvPath == p.drvPath
      && (p.editRuntime (r: r)).drvPath == p.drvPath;
    currentArgs =
      (p.override (args: {
        version = args.version;
      })).drvPath == p.drvPath;
    noLegacyFacade = !(p ? overrideAttrs) && !(p ? stdenv);
    sourceCurrent = (builtins.head probe.buildSteps).run != first.run;
    baseCurrent = (selectedCommand withBase).env.CC == "${sentinel}/bin/cc";
    environmentCurrent = (selectedCommand withEnvironment).env.FRONTEND_CONTRACT == "current";
    orderedReplay = ordered.drvPath == ((p.editRuntime (r: r)).editSteps inserted).drvPath;
    unknownRejected = rejects (p.override { unrecognizedFrontendArgument = true; }).drvPath;
    missingStepRejected = rejects (p.editSteps (steps.delete "frontend.missing")).drvPath;
    duplicateRejected = rejects (p.editSteps (steps.append [ first ])).drvPath;
    providerProjections = builtins.all (q: q ? buildEnvironment) (
      [
        p
        p.out
        (p.override { })
        (p.edit (s: s))
      ]
      ++ p.all
    );
    testsRebound =
      altered.tests.version.package.outPath == altered.outPath
      && altered.tests.version.drvPath != p.tests.version.drvPath;
    projectionTests = builtins.all (q: q.tests.version.drvPath == altered.tests.version.drvPath) (
      [
        altered.out
        altered.passthru
      ]
      ++ altered.all
    );
    testFactory =
      ((p.mkTests.override { inherit pkgs; }) altered).version.package.outPath == altered.outPath;
    ownedContext =
      (withBase.tests.version.compiler or withBase.tests.version.tvp.cc).outPath == sentinel.outPath;
  };
  failed = builtins.filter (n: !contracts.${n}) (builtins.attrNames contracts);
in
assert failed == [ ] || throw "Native ${p.pname} contracts: ${lib.concatStringsSep ", " failed}";
p.testContext.mkTest {
  package = p;
  name = "constructor";
  script = ''
    test -s ${probe}/selected-compiler
    printf '%s\n' '${builtins.toJSON contracts}' >&2
    printf qualified
  '';
  expected = "qualified";
}

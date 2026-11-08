# Common constructor controls for the native Make/M4 suites. These probes
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
  tool = p.tvp.declaredTestDependencies;
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
  flagProbe =
    (p.edit (
      s:
      s
      // {
        environment = s.environment // {
          tools = s.environment.tools ++ [ tool.pkgConfig ];
          libraries = (s.environment.libraries or [ ]) ++ [ tool.mpfr ];
          overrides = (s.environment.overrides or { }) // {
            values = (s.environment.overrides.values or { }) // {
              CFLAGS = "-O0 -std=gnu17 -DFRONTEND_FLAG=42";
              CXXFLAGS = "-O0 -DFRONTEND_FLAG=42";
              LDFLAGS = "-Wl,--as-needed";
            };
          };
        };
      }
    )).editSteps
      (
        plan:
        let
          command = builtins.head (builtins.filter (s: s ? env && s.env ? CC) plan);
        in
        [
          (
            command
            // {
              name = "frontend.user-flags-public-dependencies";
              cwd = ".";
              run = ''
                test "$CFLAGS" = '-O0 -std=gnu17 -DFRONTEND_FLAG=42'
                test "$CXXFLAGS" = '-O0 -DFRONTEND_FLAG=42'
                test "$LDFLAGS" = '-Wl,--as-needed'
                test "$PKG_CONFIG" = '${tool.pkgConfig}/bin/pkg-config'
                printf '#if FRONTEND_FLAG != 42\n#error missing_user_flag\n#endif\n' > probe.c
                cat ${../libraries/mpfr/tests/fixtures/arithmetic.c} >> probe.c
                "$CC" $CFLAGS $($PKG_CONFIG --cflags mpfr) probe.c $LDFLAGS $($PKG_CONFIG --libs mpfr) -o probe
                test "$(env -i ./probe)" = 12
                mkdir "$out"
                printf '%s\n' "$CFLAGS" "$CXXFLAGS" "$LDFLAGS" "$PKG_CONFIG" "$PKG_CONFIG_LIBDIR" > "$out/environment"
              '';
            }
          )
        ]
      );
  structured =
    (p.edit (
      s:
      s
      // {
        environment = s.environment // {
          libraries = [ tool.mpfr ];
          overrides.flags = {
            NIX_CFLAGS_COMPILE = [
              "-O0"
              "-DFRONTEND_FLAG=42"
            ];
            NIX_LDFLAGS = [ "--as-needed" ];
          };
        };
      }
    )).editSteps
      (
        plan:
        let
          c = builtins.head (builtins.filter (s: s ? env && s.env ? CC) plan);
        in
        [
          (
            c
            // {
              name = "tool.structured-flags";
              cwd = ".";
              run = ''
                printf '#if FRONTEND_FLAG != 42\n#error missing_flag\n#endif\n' > probe.c
                cat ${../libraries/mpfr/tests/fixtures/arithmetic.c} >> probe.c
                "$CC" $CFLAGS probe.c $LDFLAGS -lmpfr -lgmp -o probe
                test "$(env -i ./probe)" = 12
                mkdir "$out"
                printf structured > "$out/flags"
              '';
            }
          )
        ]
      );
  replaced =
    (
      (p.override {
        bash = tool.runtimeShell;
        coreutils = tool.alternateCoreutils;
      }).edit
      (
        s:
        s
        // {
          base = s.base.override {
            tools = map (
              t: if t.outPath == tool.coreutils.outPath then tool.alternateCoreutils else t
            ) s.base.tools;
          };
          environment = s.environment // {
            tools = [ tool.python ];
          };
        }
      )
    ).editSteps
      (
        plan:
        let
          c = builtins.head (builtins.filter (s: s ? env && s.env ? CC) plan);
        in
        [
          (
            c
            // {
              name = "tool.replaced-providers";
              cwd = ".";
              run = ''
                test "$(command -v python3)" = '${tool.python}/bin/python3'
                test "$(command -v bash)" = '${tool.runtimeShell}/bin/bash'
                test "$(command -v cat)" = '${tool.alternateCoreutils}/bin/cat'
                mkdir "$out"
                printf providers > "$out/providers"
              '';
            }
          )
        ]
      );
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
  contextProof = replaced.testContext.mkTest {
    package = p;
    name = "tool-replaced-context";
    script = ''
      test "$(command -v cat)" = '${tool.alternateCoreutils}/bin/cat'
      test "$(command -v bash)" = '${tool.runtimeShell}/bin/bash'
      printf context
    '';
    expected = "context";
  };
  batch = altered.testContext.mkBatch {
    name = "tool-custom-context";
    suite.version = altered.tests.version;
  };
  contracts = {
    noOp =
      (p.override { }).drvPath == p.drvPath
      && (p.editSteps (x: x)).drvPath == p.drvPath
      && (p.editRuntime (r: r)).drvPath == p.drvPath;
    currentArgs =
      (p.override (args: {
        version = args.version;
      })).drvPath == p.drvPath;
    batchRebound = batch.testSuite.version.package.outPath == altered.outPath;
    shellCoreutilsRebound =
      replaced.specification.bash.outPath == tool.runtimeShell.outPath
      && replaced.specification.coreutils.outPath == tool.alternateCoreutils.outPath
      && tool.alternateCoreutils.outPath != tool.coreutils.outPath
      && replaced.tests.version.specification.coreutils.outPath == tool.alternateCoreutils.outPath
      && replaced.tests.version.specification.base.shell.outPath == tool.runtimeShell.outPath;
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
    test -s ${flagProbe}/environment
    test -s ${structured}/flags
    test -s ${replaced}/providers
    test -s ${contextProof}
    test -s ${batch}/version
    printf '%s\n' '${builtins.toJSON contracts}' >&2
    printf qualified
  '';
  expected = "qualified";
}

{ pkgs, tvp }:
let
  inherit (pkgs) lib;
  base = tvp.bases.default;
  inherit (tvp.packages) bash coreutils;
  adapter = import ../../build-step-runner.nix {
    inherit
      lib
      base
      bash
      coreutils
      ;
  };
  steps = import ../../build-steps.nix;
  simple = name: run: { inherit name run; };
  fixtureTool =
    value:
    base.stdenv.mkDerivation {
      name = "step-conflict-${value}";
      dontUnpack = true;
      installPhase = ''
        mkdir -p "$out/bin"
        printf '#!${bash}/bin/bash\nprintf "%%s\\n" "${value}"\n' > "$out/bin/step-choice"
        chmod +x "$out/bin/step-choice"
      '';
      preferLocalBuild = false;
      allowSubstitutes = true;
    };
  first = fixtureTool "first";
  second = fixtureTool "second";
  disabled = builtins.derivation {
    name = "runner-disabled-never-realize";
    system = base.platform.system;
    builder = "/never-realize";
  };
  boom = throw "runner evaluated disabled/unknown payload";
  disabledSteps = [
    {
      name = "disabled.throw";
      enabled = false;
      run = boom;
      tools = boom;
      libraries = boom;
      env = boom;
      cwd = boom;
    }
    {
      name = "disabled.context";
      enabled = false;
      run = "${disabled}";
      tools = [ disabled ];
      libraries = [ disabled ];
      env.DATA = "${disabled}";
    }
  ];
  successPlan =
    steps.insertBefore "fixture.last" [ (simple "custom.inserted" "printf 'inserted\\n' >> order") ]
      (
        steps.replace "fixture.last" (old: old // { run = "printf 'replaced\\n' >> order"; }) (
          steps.namespace "fixture" [
            {
              name = "first";
              run = ''
                printf 'first\n' >> order
                mkdir 'space dir'
                mkdir $'literal \n ; $(touch forbidden-quote)'
                export LEAK=bad
                set +e
                trap 'echo leaked >&2' EXIT
                f() { :; }
                cd 'space dir'
              '';
            }
            {
              name = "second";
              run = ''
                test -z "''${LEAK-}"
                ! declare -F f
                test -z "$(trap -p EXIT)"
                [[ $- == *e* && $- == *u* ]]
                shopt -q inherit_errexit
                [[ $SHELLOPTS == *pipefail* ]]
                test -f order
                printf 'second\n' >> order
              '';
            }
            {
              name = "last";
              run = "exit 99";
            }
          ]
          ++ steps.namespace "assets" [
            {
              name = "short";
              cwd = "space dir";
              run = ":";
            }
          ]
          ++ disabledSteps
        )
      );
  cases = {
    success = successPlan;
    streams = [
      {
        name = "bytes.streams";
        env.VALUE = " a ' \" $() ;\nlast\n";
        run = ''printf '%s' "$VALUE"; printf 'err  \nsecond' >&2'';
      }
    ];
    exit7 = [ (simple "failure.seven" "exit 7") ];
    false = [ (simple "failure.false" "false; echo unreachable") ];
    pipeline = [ (simple "failure.pipeline" "false | true; echo unreachable") ];
    substitution = [
      (simple "failure.substitution" ''value=$(false; echo unreachable); echo unreachable'')
    ];
    function = [ (simple "failure.function" "f() { false; echo unreachable; }; f; echo unreachable") ];
    source = [
      (simple "failure.source" ''printf 'false; echo unreachable\n' > sourced; source ./sourced; echo unreachable'')
    ];
    exit143 = [ (simple "failure.numeric" "exit 143") ];
    signal143 = [ (simple "failure.numeric" ''kill -TERM "$$"'') ];
    handled = [ (simple "handled.condition" "if false; then exit 9; fi; ! false; false || :") ];
    missing = [
      {
        name = "cwd.missing";
        cwd = "absent dir";
        run = "echo unreachable";
      }
    ];
    literalCwd = [
      (simple "cwd.prepare" "mkdir 'literal \n ; $(touch forbidden-quote)'; printf ok > order")
      {
        name = "cwd.literal";
        cwd = "literal \n ; $(touch forbidden-quote)";
        run = "test -f ../order";
      }
    ];
    scopes = [
      {
        name = "tools.first";
        tools = [ first ];
        env.LOCAL = "one";
        run = ''test "$(step-choice)" = first; printf '%s' "$LOCAL" > local; export EXTRA=leak'';
      }
      {
        name = "tools.second";
        tools = [ second ];
        run = ''test "$(step-choice)" = second; test -z "''${LOCAL-}''${EXTRA-}"'';
      }
      {
        name = "tools.none";
        run = "! command -v step-choice";
      }
      {
        name = "library.present";
        libraries = [ tvp.packages.zlib ];
        run = ''[[ "$NIX_CFLAGS_COMPILE" == *"${tvp.packages.zlib}/include"* ]]; [[ "$NIX_LDFLAGS" == *"${tvp.packages.zlib}/lib"* ]]'';
      }
      {
        name = "library.absent";
        run = ''[[ "''${NIX_CFLAGS_COMPILE-}" != *"${tvp.packages.zlib}/include"* ]]; [[ "''${NIX_LDFLAGS-}" != *"${tvp.packages.zlib}/lib"* ]]'';
      }
    ];
    lists = [
      {
        name = "inputs.lists";
        tools = [
          first
          second
        ];
        libraries = [
          tvp.packages.zlib
          tvp.packages.libffi
        ];
        run = ''
          test "$(step-choice)" = first
          [[ "$NIX_CFLAGS_COMPILE" == *"${tvp.packages.zlib}/include"* ]]
          [[ "$NIX_CFLAGS_COMPILE" == *"${tvp.packages.libffi}/include"* ]]
        '';
      }
    ];
    compiler = [
      {
        name = "compiler.smoke";
        libraries = [ tvp.packages.zlib ];
        run = ''
          cat > smoke.c <<'C'
          #include <zlib.h>
          #include <stdio.h>
          int main(void) { puts(zlibVersion()); return 0; }
          C
          "$CC" smoke.c -lz -o smoke
          ./smoke
        '';
      }
    ];
    cancel = [
      {
        name = "cancel.active";
        run = ''
          printf '%s\n' "$$" > leader.pid
          # A nested ordinary Bash with its own child; cooperative traps reap each.
          ${bash}/bin/bash -c '
            trap "wait; exit 0" INT TERM HUP
            printf "%s\n" "$$" > nested.pid
            sleep 60 &
            printf "%s\n" "$!" > leaf.pid
            printf ready > ready
            wait
          ' &
          trap 'wait; exit 0' INT TERM HUP
          wait
        '';
      }
    ];
  };
  plans = lib.mapAttrs (
    name: plan:
    adapter {
      plan = plan ++ lib.optional (name != "success") (simple "later.forbidden" "echo later > forbidden");
    }
  ) cases;
  # Actual adapter context regression, including unknown metadata and missing run.
  contextPlan = adapter {
    plan = [
      {
        name = "context.active";
        run = "${first}/bin/step-choice";
        metadata = boom;
      }
    ] ++ disabledSteps;
  };
  synthetic =
    name:
    builtins.derivation {
      inherit name;
      system = base.platform.system;
      builder = "/never-realize";
    };
  contextInputs = map synthetic [
    "runner-context-tool"
    "runner-context-library"
    "runner-context-env"
    "runner-context-run"
    "runner-context-cwd"
  ];
  projection = adapter {
    plan = [
      {
        name = "context.all";
        tools = [ (builtins.elemAt contextInputs 0) ];
        libraries = [ (builtins.elemAt contextInputs 1) ];
        env.DATA = "${builtins.elemAt contextInputs 2}";
        run = "${builtins.elemAt contextInputs 3}/run";
        cwd = "${builtins.elemAt contextInputs 4}/source";
        unknown = boom;
      }
    ] ++ disabledSteps;
  };
  projectedContext = builtins.getContext (lib.concatStrings projection.childScripts);
  rejects = value: !(builtins.tryEval (builtins.deepSeq value true)).success;
  badEnv =
    key:
    (adapter {
      plan = [
        {
          name = "invalid.env";
          env.${key} = "bad";
          run = ":";
        }
      ];
    }).text;
  contracts = {
    disabledContext =
      !(builtins.hasAttr (builtins.unsafeDiscardStringContext disabled.drvPath) (
        builtins.getContext (lib.concatStrings contextPlan.childScripts)
      ));
    activeContext = builtins.hasAttr (builtins.unsafeDiscardStringContext first.drvPath) (
      builtins.getContext (lib.concatStrings contextPlan.childScripts)
    );
    allActiveContexts = builtins.all (
      p: builtins.hasAttr (builtins.unsafeDiscardStringContext p.drvPath) projectedContext
    ) contextInputs;
    noDisabledProjection =
      !(builtins.hasAttr (builtins.unsafeDiscardStringContext disabled.drvPath) projectedContext);
    activeOnlyInputs = (adapter { plan = disabledSteps; }).inputs == [ ];
    malformed = rejects (badEnv "bad-key");
    shellControl = rejects (badEnv "BASH_ENV");
    loggingControl = rejects (badEnv "NIX_LOG_FD");
    pathControl = rejects (badEnv "PATH");
    runnerControl = rejects (badEnv "TVP_CURRENT");
    compilerEnv =
      !(rejects (
        (adapter {
          plan = [
            {
              name = "valid.compiler";
              env = {
                NIX_CFLAGS_COMPILE = "-O0";
                CC = "cc";
                CXX = "c++";
              };
              run = ":";
            }
          ];
        }).text
      ));
    missingRun = rejects (adapter { plan = [ { name = "invalid.missing"; } ]; }).text;
    duplicateDisabled = rejects (adapter { plan = disabledSteps ++ disabledSteps; }).text;
  };
  failed = builtins.filter (n: !contracts.${n}) (builtins.attrNames contracts);
  # Runtime artifact has no reference to the Python test harness.
  runtime = builtins.derivation {
    name = "tvp-build-step-runner-fixture-runtime";
    inherit (base.platform) system;
    builder = "${bash}/bin/bash";
    args = [
      "-euc"
      ''
        ${coreutils}/bin/mkdir -p "$out"
        ${lib.concatStringsSep "\n" (
          lib.mapAttrsToList (name: value: "${coreutils}/bin/cp ${value.script} \"$out/${name}\"") plans
        )}
      ''
    ];
    preferLocalBuild = false;
    allowSubstitutes = true;
  };
in
assert failed == [ ] || throw "Runner contracts failed: ${lib.concatStringsSep ", " failed}";
(builtins.derivation {
  name = "tvp-build-step-runner-contracts";
  outputs = [ "out" ];
  inherit (base.platform) system;
  builder = "${bash}/bin/bash";
  args = [
    "-euc"
    ''
      export PATH=${coreutils}/bin
      export PYTHONDONTWRITEBYTECODE=1
      ${tvp.packages.python_3}/bin/python3 ${./harness.py} ${runtime} ${bash}/bin/bash
      printf '%s\n' '${builtins.toJSON contracts}' > "$out"
    ''
  ];
  preferLocalBuild = false;
  allowSubstitutes = true;
})
// {
  passthru = {
    inherit runtime contracts;
  };
}

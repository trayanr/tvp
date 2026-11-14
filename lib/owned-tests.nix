# Test construction on an explicitly selected owned base, without setup hooks.
{ lib }:
{
  builder,
  base,
  coreutils,
}:
let
  quote = lib.escapeShellArg;
  safeName =
    name:
    if builtins.isString name && builtins.match "[A-Za-z0-9][A-Za-z0-9._+-]*" name != null then
      name
    else
      throw "TVP owned tests: unsafe name";
  make =
    recipe: args: dependencies:
    builder {
      inherit recipe args;
      dependencyNames = dependencies;
      infrastructure = {
        shell = base.shell;
        inherit coreutils;
      };
      metadata.kind = "owned-test";
      selection.kind = "owned-test";
      mkTests = _: { };
    };
in
rec {
  mkTest =
    {
      package,
      name,
      script,
      expected,
      tools ? [ ],
      libraries ? [ ],
      environment ? { },
    }:
    assert builtins.isString script || throw "TVP owned tests: script must be a string";
    assert builtins.isString expected || throw "TVP owned tests: expected must be a string";
    make
      (
        {
          package,
          tools,
          libraries,
        }:
        final: {
          pname = "${package.pname}-${package.version}-${safeName name}";
          version = "test";
          src = null;
          inherit base coreutils;
          bash = final.base.shell;
          passthru = {
            inherit package;
            testName = name;
          };
          plan = [
            (
              (final.base.environment {
                tools = [
                  package
                  coreutils
                ] ++ tools;
                inherit libraries;
                overrides = environment;
              })
              // {
                name = "test.compare";
                run = ''
                  # Standalone assignment preserves errexit inside the substitution.
                  # Bash removes trailing newlines; expected remains literal.
                  actual=$(
                  ${script}
                  )
                  expected=${quote expected}
                  if [[ "$actual" != "$expected" ]]; then
                    printf 'FAIL  %s / %s\n  expected: %s\n  actual:   %s\n' \
                      ${quote "${package.pname} ${package.version}"} ${quote name} "$expected" "$actual" >&2
                    exit 1
                  fi
                  printf '%s\n' "$actual" > "$out"
                '';
              }
            )
          ];
        }
      )
      { inherit package tools libraries; }
      [
        "package"
        "tools"
        "libraries"
      ];

  mkUpstream = import ./upstream-checkpoint-tests.nix;

  mkSuite =
    {
      package,
      tests,
      tools ? [ ],
      libraries ? [ ],
      environment ? { },
    }:
    builtins.mapAttrs (
      name: spec:
      mkTest (
        {
          inherit
            package
            tools
            libraries
            environment
            ;
        }
        // spec
        // {
          inherit name;
        }
      )
    ) tests;

  mkBatch =
    { name, suite }:
    make (
      { suite }:
      final: {
        pname = "tvp-tests-${safeName name}";
        version = "1";
        src = null;
        inherit base coreutils;
        bash = final.base.shell;
        passthru.testSuite = suite;
        plan = [
          (
            (final.base.environment { tools = [ coreutils ]; })
            // {
              name = "tests.link";
              run = ''
                mkdir -- "$out"
                ${lib.concatStringsSep "\n" (
                  map (
                    testName: "ln -s -- ${quote (toString suite.${testName})} \"$out\"/${quote (safeName testName)}"
                  ) (builtins.attrNames suite)
                )}
              '';
            }
          )
        ];
      }
    ) { inherit suite; } [ "suite" ];
}

# Whole preparation preflight plus actual selected runtime execution through the
# package's complete finalization suffix. The artifact is reused by the latter.
{ tvp, package }:
let
  s = package.specification;
  tools = with package.tvp.declaredDependencies; [
    python
    sed
    grep
    gawk
    diffutils
    binutils
  ];
  provider = tvp.builder {
    metadata = { };
    selection.kind = "owned-test-support";
    dependencyNames = [
      "bash"
      "coreutils"
    ];
    mkTests = _: { };
    recipe =
      {
        base,
        bash,
        coreutils,
      }:
      final: {
        pname = "attr-crypt-runtime-provider";
        version = "1";
        inherit base bash coreutils;
        plan = [
          {
            name = "provider.install";
            run = ''
              mkdir -p "$out/bin"
              cat > "$out/bin/bash" <<'EOF'
              #!${bash}/bin/bash
              printf 'selected-shell\n' >> "$TVP_PROVIDER_LOG"
              exec ${bash}/bin/bash "$@"
              EOF
              cat > "$out/bin/probe-provider" <<'EOF'
              #!${bash}/bin/bash
              printf 'selected-tool\n'
              EOF
              chmod +x "$out/bin/bash" "$out/bin/probe-provider"
            '';
          }
        ];
      };
    args = {
      inherit (s) base bash coreutils;
    };
  };
  runtime =
    (package.editSteps (
      tvp.builder.steps.insertAfter "output.copy-artifacts" [
        {
          name = "contract.helper";
          run = ''
            mkdir -p "$out/bin"
            cat > "$out/bin/runtime-probe" <<'EOF'
            #!/bin/sh
            /bin/sh -c 'probe-provider'
            EOF
            chmod +x "$out/bin/runtime-probe"
          '';
        }
      ]
    )).editRuntime
      (
        r:
        r
        // {
          shell = provider;
          tools = [ provider ] ++ r.tools;
        }
      );
in
assert runtime.artifact.drvPath == package.artifact.drvPath;
assert runtime.drvPath != package.drvPath;
package.testContext.mkSuite {
  inherit package tools;
  tests = {
    confinement = {
      script = ''
        ${s.python}/bin/python3 -B ${./ordinary-attr-crypt-tests.py} \
          ${./ordinary-attr-crypt-source.py} ${./ordinary-attr-crypt-output.py} \
          ${s.bash}/bin/bash ${s.perl}/bin/perl ${s.binutils}/bin/readelf ${s.patchelf}/bin/patchelf
      '';
      expected = "ok";
    };
    runtime-provider = {
      script = ''
        ${s.coreutils}/bin/env -i TVP_PROVIDER_LOG="$PWD/provider.log" ${runtime}/bin/runtime-probe
        test "$(wc -l < provider.log)" = 2
        echo ok
      '';
      expected = "selected-tool\nok";
    };
  };
}

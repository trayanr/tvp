# Final-only edits reuse A; source/environment edits change their own variants.
{
  package,
  context,
  lib,
}:
let
  p = package;
  s = p.specification;
  runtime = p.editRuntime (r: r // { dlopenDirectories = [ "${s.base.standardTools.python}/lib" ]; });
  suffix = p.editSteps (
    plan:
    plan
    ++ [
      {
        name = "ordinary.final-control";
        run = ''mkdir -p "$out/nix-support"; printf selected > "$out/nix-support/final-control"'';
      }
    ]
  );
  source = p.override { src = "${p.tvp.declaredTestDependencies.alternateSource}/source.tar.gz"; };
  build = p.edit (
    spec:
    spec
    // {
      environment = spec.environment // {
        overrides = (spec.environment.overrides or { }) // {
          values = (spec.environment.overrides.values or { }) // {
            ORDINARY_BUILD_INPUT = "changed";
          };
        };
      };
    }
  );
  disabled = p.override { doCheck = false; };
in
assert (p.override { }).drvPath == p.drvPath && (p.edit (spec: spec)).drvPath == p.drvPath;
assert (p.mkTests p).version.drvPath == p.tests.version.drvPath;
assert runtime.artifact.drvPath == p.artifact.drvPath && runtime.drvPath != p.drvPath;
assert suffix.artifact.drvPath == p.artifact.drvPath && suffix.drvPath != p.drvPath;
assert source.artifact.drvPath != p.artifact.drvPath;
assert build.artifact.drvPath != p.artifact.drvPath;
assert disabled.artifact.drvPath == p.artifact.drvPath && disabled.drvPath == p.drvPath;
assert !(disabled.tests ? upstream);
context.mkTest {
  inherit package;
  name = "split";
  tools = [
    suffix
    runtime
  ];
  script = ''
    test "$(cat ${suffix}/nix-support/final-control)" = selected
    ${runtime}/bin/make --version >&2
    printf split
  '';
  expected = "split";
}

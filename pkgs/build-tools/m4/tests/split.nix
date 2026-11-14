# Test-only and final-only changes preserve the completed compilation artifact.
{ package, context }:
let
  p = package;
  noCheck = p.override { doCheck = false; };
  shell = p.tvp.declaredTestDependencies.runtimeShell;
  runtime = noCheck.editRuntime (r: r // { inherit shell; });
  suffix = noCheck.editSteps (
    plan:
    plan
    ++ [
      {
        name = "m4.final-control";
        run = ''mkdir -p "$out/nix-support"; printf selected > "$out/nix-support/final-control"'';
      }
    ]
  );
  same = q: q.artifact.drvPath == p.artifact.drvPath && q.drvPath == p.drvPath;
in
assert same noCheck;
assert runtime.artifact.drvPath == p.artifact.drvPath && runtime.drvPath != p.drvPath;
assert suffix.artifact.drvPath == p.artifact.drvPath && suffix.drvPath != p.drvPath;
context.mkTest {
  inherit package;
  name = "split";
  tools = [
    runtime
    suffix
  ];
  script = ''
    test "$(cat ${suffix}/nix-support/final-control)" = selected
    ${runtime}/bin/m4 --version >&2
    printf split
  '';
  expected = "split";
}

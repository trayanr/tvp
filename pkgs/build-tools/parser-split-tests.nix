# These finite controls run against the effective ordinary package.
{
  package,
  lib,
  context,
}:
let
  p = package;
  tools = p.specification.base.tools;
  t = p.tvp.declaredTestDependencies;
  runtime = p.editRuntime (r: r // { dlopenDirectories = [ "${tools.python}/lib" ]; });
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
  source = p.edit (s: s // { src = p.tvp.declaredTestDependencies.alternateSource; });
  build = p.edit (
    s:
    s
    // {
      environment = s.environment // {
        overrides.values.ORDINARY_BUILD_INPUT = "changed";
      };
    }
  );
  unchanged = (p.override { }).drvPath == p.drvPath && (p.edit ((s: s))).drvPath == p.drvPath;
  yaccShell = p.editSteps (
    map (
      step:
      if step.name == "output.shebangs" then
        step // { run = step.run + "\n# finalizer-specific cache control"; }
      else
        step
    )
  );
in
assert unchanged;
assert ((p.mkTests p).version.drvPath == p.tests.version.drvPath);
assert
  (p.edit (s: s // { base = s.base.override { compiler = t.sentinel; }; })).artifact.drvPath
  != p.artifact.drvPath;
assert runtime.artifact.drvPath == p.artifact.drvPath && runtime.drvPath != p.drvPath;
assert suffix.artifact.drvPath == p.artifact.drvPath && suffix.drvPath != p.drvPath;
assert source.artifact.drvPath != p.artifact.drvPath;
assert build.artifact.drvPath != p.artifact.drvPath;
assert
  p.pname != "bison"
  || (yaccShell.artifact.drvPath == p.artifact.drvPath && yaccShell.drvPath != p.drvPath);
context.mkTest {
  package = p;
  name = "split";
  tools = [
    tools.python
    tools.patchelf
    p.specification.base.coreutils
  ];
  script = ''
    ${tools.python}/bin/python3 -B ${../../lib/tests/ordinary-rpaths.py} \
      ${../../lib/relocate.py} ${tools.patchelf}/bin/patchelf \
      ${p.specification.base.coreutils}/bin/true >&2
    test "$(cat ${suffix}/nix-support/final-control)" = selected
    ${runtime}/bin/${p.pname} --version >&2
    printf split
  '';
  expected = "split";
}

# Historical-era installed controls use each effective interface profile.
# Upstream acceptance belongs to the package's independent checkpoint leaf.
{
  package,
  lib,
  context,
}:
let
  p = package;
  tools = p.specification.base.standardTools;
  runtime = p.editRuntime (r: r // { shell = p.tvp.declaredTestDependencies.runtimeShell; });
  source = p.edit (s: s // { src = p.tvp.declaredTestDependencies.alternateSource; });
in
context.mkSuite {
  package = p;
  tests = {
    helper-confinement-and-frontends = {
      script = ''
        ${tools.python}/bin/python3 -B ${./ordinary-autotools-safety-tests.py} \
          ${./ordinary-autotools-source.py} ${./automake/prepare-api.py} \
          ${./ordinary-autotools-output.py} ${./historical-autotools-output.py}
      '';
      expected = "helper-contracts";
    };
    artifact-finalization = {
      expected =
        assert (p.override { }).drvPath == p.drvPath;
        assert (p.edit (s: s)).drvPath == p.drvPath;
        assert runtime.artifact.drvPath == p.artifact.drvPath;
        assert runtime.drvPath != p.drvPath;
        assert source.artifact.drvPath != p.artifact.drvPath;
        assert p.out.artifact.drvPath == p.artifact.drvPath;
        assert (builtins.head p.all).drvPath == p.drvPath;
        "split";
      script = ''
        env -i PATH=/absent ${runtime}/bin/${p.pname} --version >&2
        printf split
      '';
    };
  };
}

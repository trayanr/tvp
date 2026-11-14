# Finalization-specific reuse and effective-input contracts for the ordinary ports.
{
  package,
  lib,
  context,
}:
let
  p = package;
  tools = p.specification.base.standardTools;
  steps = import ../../lib/build-steps.nix;
  t = p.tvp.declaredTestDependencies;
  runtime = p.editRuntime (
    r: r // { shell = t.runtimeShell; } // lib.optionalAttrs (r ? perl) { perl = t.alternatePerl; }
  );
  source = p.edit (s: s // { src = t.alternateSource; });
  compiler = p.edit (s: s // { base = s.base.override { compiler = t.sentinel; }; });
  finalizer = p.editSteps (
    steps.replace "${p.pname}.relocate-runtime" (
      s: s // { run = s.run + "\nprintf finalizer-control > \"$out/finalizer-control\"\n"; }
    )
  );
  api = p.edit (s: s // { version = "1.88.4"; });
  contracts = {
    noOp = (p.override { }).drvPath == p.drvPath && (p.edit (s: s)).drvPath == p.drvPath;
    runtimeArtifact = runtime.artifact.drvPath == p.artifact.drvPath;
    runtimeFinal = runtime.drvPath != p.drvPath;
    finalizerArtifact = finalizer.artifact.drvPath == p.artifact.drvPath;
    finalizerFinal = finalizer.drvPath != p.drvPath;
    sourceArtifact = source.artifact.drvPath != p.artifact.drvPath;
    compilerArtifact = compiler.artifact.drvPath != p.artifact.drvPath;
    versionLayout =
      p.pname != "automake"
      || (api.specification.apiVersion == "1.88" && api.artifact.drvPath != p.artifact.drvPath);
    factory =
      ((p.mkTests.override { tests = import (./. + "/${p.pname}/tests"); }) p).version.package.outPath
      == p.outPath;
  };
in
context.mkSuite {
  package = p;
  tools = [ tools.grep ];
  tests =
    {
      helper-confinement-and-frontends = {
        script = ''
          ${tools.python}/bin/python3 -B ${./ordinary-autotools-safety-tests.py} \
            ${./ordinary-autotools-source.py} ${./automake/prepare-api.py} \
            ${./ordinary-autotools-output.py}
        '';
        expected = "helper-contracts";
      };
      artifact-finalization = {
        expected =
          assert lib.all (x: x) (builtins.attrValues contracts);
          "split";
        script = ''
          test -s ${finalizer}/finalizer-control
          head -1 ${runtime}/bin/${p.pname} | grep -Fq '${
            if
              p.specification ? perl
              && (p.specification.installedInterface.frontends.autoconf or "perl") == "perl"
            then
              "${runtime.runtime.perl}/bin/perl"
            else
              "${runtime.runtime.shell}/bin/bash"
          }'
          env -i PATH=/absent ${runtime}/bin/${p.pname} --version >&2
          printf split
        '';
      };
    }
    // lib.optionalAttrs (p.pname == "automake" && (p.tvp.features.configuredApi or false)) {
      effective-version-layout = {
        script = ''
          test -s ${api}/share/automake-1.88/depcomp
          test -d ${api}/share/aclocal-1.88
          test "$(readlink ${api}/bin/automake-1.88)" = automake
          env -i PATH=/absent ${api}/bin/automake-1.88 --version | head -1 | grep -Fq 1.88.4
          env -i PATH=/absent ${runtime}/share/automake-${p.specification.apiVersion}/test-driver --help | grep -Fq Usage
          printf layout
        '';
        expected = "layout";
      };
    };
}

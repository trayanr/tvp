# Pure edit/projection controls: no edited source/compiler is realized here.
{
  lib,
  tvp,
  package,
}:
let
  p = package;
  s = p.specification;
  inherit (tvp.builder) steps;
  has =
    needle: q:
    builtins.any (
      step:
      lib.hasInfix (builtins.unsafeDiscardStringContext needle) (
        builtins.unsafeDiscardStringContext (step.run or "")
      )
    ) q.buildSteps;
  reuse = q: p.artifact.drvPath == q.artifact.drvPath && p.drvPath != q.drvPath;
  rebuild = q: p.artifact.drvPath != q.artifact.drvPath;
  shell = tvp.packages.bash_5;
  shellEdit = p.edit (x: x // { runtimeShell = shell; });
  runtimeEdit = p.editRuntime (r: r // { inherit shell; });
  loaderEdit = p.editRuntime (r: r // { loader = "${r.loader}.control"; });
  librariesEdit = p.editRuntime (r: r // { libraries = r.libraries ++ [ s.compiler ]; });
  libc = s.runtimeLibc // {
    outPath = "${s.runtimeLibc.outPath}.control";
  };
  libcEdit = p.edit (x: x // { runtimeLibc = libc; });
  compilerEdit = p.edit (
    x:
    x
    // {
      compiler = s.compiler // {
        outPath = "${s.compiler.outPath}.control";
      };
    }
  );
  sourceEdit = p.edit (
    x: x // { src = builtins.toFile "go-bootstrap-source-control" "source changed"; }
  );
  prefix = p.editSteps (
    steps.replace "go-bootstrap.build" (old: old // { run = old.run + "\n: prefix-control"; })
  );
  suffix = p.editSteps (
    steps.append [
      {
        name = "go-bootstrap.suffix-control";
        run = ": suffix-control";
      }
    ]
  );
  rejects = q: !(builtins.tryEval (builtins.deepSeq q.drvPath true)).success;
  contracts = {
    split = (steps.partition p.buildSteps).split && p.artifact.drvPath != p.drvPath;
    exclusion = builtins.elem p.artifact p.outputChecks.out.disallowedReferences;
    source = rebuild sourceEdit && sourceEdit.src == sourceEdit.specification.src;
    compiler =
      rebuild compilerEdit
      && has "${compilerEdit.specification.compiler}/bin/cc" compilerEdit
      && compilerEdit.tvp.cc.outPath == compilerEdit.specification.compiler.outPath
      && compilerEdit.compiler.outPath == compilerEdit.specification.compiler.outPath;
    standard = rebuild (p.override { cStandard = "gnu11"; });
    compiledRoot = rebuild (p.edit (x: x // { compiledRoot = "/tvp/go-bootstrap-control"; }));
    stepPrefix = rebuild prefix;
    stepSuffix = reuse suffix;
    runtimeLoader = reuse loaderEdit && has loaderEdit.runtime.loader loaderEdit;
    runtimeLibraries =
      reuse librariesEdit
      && has "${s.compiler}" librariesEdit
      && librariesEdit.runtime.libraries == librariesEdit.tvp.runtimeProviders.libraries;
    runtimeShell =
      reuse runtimeEdit
      && runtimeEdit.tvp.deps.runtimeShell.drvPath == shell.drvPath
      && has "${shell}/bin/bash" runtimeEdit;
    directShell =
      shellEdit.drvPath == runtimeEdit.drvPath
      && shellEdit.drvPath == (p.override { runtimeShell = shell; }).drvPath;
    directLibc =
      reuse libcEdit
      && libcEdit.runtime.libc.outPath == libc.outPath
      && libcEdit.tvp.deps.runtimeLibc.outPath == libc.outPath
      && has libcEdit.runtime.loader libcEdit;
    testRebinding = runtimeEdit.tests.nested-bootstrap.drvPath != p.tests.nested-bootstrap.drvPath;
    reportedVersion =
      let
        q = p.edit (x: x // { reportedVersion = "control-version"; });
      in
      rebuild q
      && q.tvp.reportedVersion == "control-version"
      && q.tests.version.drvPath != p.tests.version.drvPath;
    cgoReject = rejects (p.edit (x: x // { cgo = true; }));
    platformReject = rejects (p.override { goArch = "arm64"; });
  };
in
{
  inherit contracts;
  runtime = runtimeEdit;
  leaking = p.editSteps (
    steps.append [
      {
        name = "go-bootstrap.leak-control";
        run = ''printf '%s' '${p.artifact}' > "$out/forbidden-reference"'';
      }
    ]
  );
}

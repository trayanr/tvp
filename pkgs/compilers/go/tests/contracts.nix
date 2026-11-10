{
  lib,
  package,
  alternate,
  alternateCompiler,
}:
let
  p = package;
  s = p.specification;
  has =
    a: b:
    lib.hasInfix (builtins.unsafeDiscardStringContext (toString a)) (
      builtins.unsafeDiscardStringContext b
    );
  run = p: name: (builtins.head (builtins.filter (x: x.name == name) p.buildSteps)).run;
  changed = p.edit (
    s:
    s
    // {
      bootstrap = alternate;
      helperPython = alternate;
      binutils = alternate;
      patchelf = alternate;
      bash = alternate;
      coreutils = alternate;
    }
  );
  custom = p.edit (
    s:
    s
    // {
      environment = s.environment // {
        overrides.values = {
          CC = "${alternate}/custom-cc";
          CXX = "${alternate}/custom-cxx";
        };
      };
    }
  );
  base = p.edit (s: s // { base = s.base.override { name = "go-base-contract"; }; });
  runtime = p.editRuntime (r: r // { libc = alternate; });
  compiler = p.editRuntime (r: r // { compiler = alternateCompiler; });
  unsupportedCompiler = p.editRuntime (r: r // { compiler = alternate; });
in
{
  owned = !(p ? stdenv) && s.base.name == "source-gnu-candidate";
  makeShellTools =
    builtins.elem s.sed s.environment.tools && builtins.elem s.grep s.environment.tools;
  seed = s.bootstrap.version == "1.24.13";
  direct = has "./make.bash" (run p "go.build") && has "${s.bootstrap}/share/go" (run p "go.build");
  bootstrap = has "${alternate}/share/go" (run changed "go.build");
  helpers =
    has "${alternate}/bin/python3" (run changed "go.prepare")
    && has "${alternate}/bin/patchelf" (run changed "output.check-paths");
  compilerDefault =
    s.runtime.cc == "${s.base.compiler}/bin/cc" && s.runtime.cxx == "${s.base.compiler}/bin/c++";
  compilerOverride =
    has "${alternate}/custom-cc" (run custom "go.build")
    && has "${alternate}/custom-cxx" (run custom "go.build")
    && has "${alternate}/custom-cc" (builtins.head custom.tests.compiler-default.buildSteps).run;
  rejectIncoherentLibc = !(builtins.tryEval runtime.drvPath).success;
  rejectUnsupportedCompiler = !(builtins.tryEval unsupportedCompiler.drvPath).success;
  runtimeCompiler =
    compiler.drvPath != p.drvPath
    && compiler.specification.runtime.cc == "${alternateCompiler}/bin/cc"
    && compiler.specification.runtime.cxx == "${alternateCompiler}/bin/c++"
    && has "${alternateCompiler}/bin/cc" (run compiler "go.build")
    && has "${alternateCompiler}/bin/c++" (run compiler "go.build");
  compilerLibc =
    compiler.specification.runtime.libc.drvPath == alternateCompiler.libc.drvPath
    && has "${alternateCompiler.libc}/${s.dynamicLinker}" (run compiler "go.build")
    && has "${alternateCompiler.libc}/${s.dynamicLinker}" (builtins.head compiler.tests.cgo.buildSteps)
    .run;
  compilerTests =
    has "${alternateCompiler}/bin/cc" (builtins.head compiler.tests.compiler-default.buildSteps).run
    && builtins.elem alternateCompiler.drvPath (
      map (t: t.drvPath) compiler.tests.compiler-default.tvp.deps.tools
    );
  metadata =
    changed.tvp.deps.bootstrap.outPath == alternate.outPath
    && changed.tvp.deps.coreutils.outPath == alternate.outPath;
  tests =
    builtins.attrNames p.tests == [
      "cgo"
      "compile"
      "compiler-default"
      "modules"
      "standard-library"
      "toolchain-default"
      "version"
    ];
  rebound =
    changed.tests.version.package.drvPath == changed.drvPath
    && changed.tests.version.drvPath != p.tests.version.drvPath;
  baseTest = base.tests.version.specification.base.name == "go-base-contract";
  shellTest = changed.tests.version.specification.bash.outPath == alternate.outPath;
}

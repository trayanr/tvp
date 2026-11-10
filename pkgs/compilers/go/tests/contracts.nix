{
  lib,
  package,
  alternate,
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
  loader =
    has "${alternate}/lib/ld-linux-x86-64.so.2" (run runtime "go.build")
    && has "${alternate}/lib/ld-linux-x86-64.so.2" (builtins.head runtime.tests.cgo.buildSteps).run;
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

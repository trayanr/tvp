# Bounded evaluation-only contracts; no output or compiler execution.
{
  lib,
  builder,
  package,
  alternate,
}:
let
  p = package;
  s = p.specification;
  parts = builder.steps.partition p.buildSteps;
  names = xs: map (x: x.name) xs;
  edit = fields: p.edit (s: s // fields);
  runtime = p.editRuntime (
    r:
    r
    // {
      shell = alternate;
      python = alternate;
      perl = alternate;
      loader = "${alternate}/lib/ld-linux-x86-64.so.2";
      target = lib.mapAttrs (_: _: alternate) r.target;
      libraries = [ alternate ];
    }
  );
  finalizer = edit {
    finalizer = builtins.toFile "llvm-finalizer-contract.py" "raise RuntimeError('fixture')\n";
  };
  archiveModule = edit {
    archiveElfFinalizer = builtins.toFile "llvm-archive-elf-contract.py" "raise RuntimeError('fixture')\n";
  };
  upstreamEdit = edit { upstreamCheck = "exit 23"; };
  source = p.override { src = builtins.toFile "llvm-source-contract" "fixture"; };
  compiler = edit { base = s.base.override { compiler = alternate; }; };
  headers = edit { zlib = alternate; };
  build = edit { cmakeFlags = s.cmakeFlags ++ [ "-DCONTRACT_ONLY=1" ]; };
  upstream = p.edit (
    spec:
    (builtins.removeAttrs spec [ "artifactName" ])
    // {
      pname = "${spec.pname}-upstream";
      validationRole = "upstream-execution";
      plan = spec.upstreamPlan;
      passthru = { };
    }
  );
  runs = xs: lib.concatMapStringsSep "\n" (x: x.run or "") xs;
  upstreamContext = builtins.getContext (runs upstream.buildSteps);
in
{
  realSplit = parts.split && p.artifact.drvPath != p.drvPath && p.artifact.outPath != p.outPath;
  scalarOnly =
    p.outputs == [ "out" ] && !(lib.hasInfix "TVP_ARTIFACT_OUTPUTS" (builtins.head parts.second).run);
  equalWidth = builtins.stringLength p.outPath == builtins.stringLength p.artifact.outPath;
  installLast = lib.last (names parts.first) == "llvm.install";
  copyFirst = (builtins.head parts.second).name == "output.copy-artifacts";
  noEarlyRepair =
    names parts.first == [
      "source.unpack"
      "llvm.configure"
      "llvm.build"
      "llvm.install"
    ];
  testPreparationSeparate =
    builtins.elem "-DLLVM_INCLUDE_TESTS=OFF" s.cmakeFlags
    && builtins.elem "-DLLVM_INCLUDE_TESTS=ON" s.upstreamCmakeFlags;
  rawProvenance =
    lib.hasInfix "cp build/CMakeCache.txt" (runs parts.first)
    && lib.hasInfix "rm -- \"$out/nix-support/CMakeCache.txt\"" (runs parts.second);
  finalizerReuse = finalizer.artifact.drvPath == p.artifact.drvPath && finalizer.drvPath != p.drvPath;
  archiveModuleReuse =
    archiveModule.artifact.drvPath == p.artifact.drvPath && archiveModule.drvPath != p.drvPath;
  runtimeReuse = runtime.artifact.drvPath == p.artifact.drvPath && runtime.drvPath != p.drvPath;
  testReuse =
    upstreamEdit.artifact.drvPath == p.artifact.drvPath
    && upstreamEdit.drvPath == p.drvPath
    && upstreamEdit.tests.upstream.drvPath != p.tests.upstream.drvPath;
  sourceInvalidates = source.artifact.drvPath != p.artifact.drvPath;
  compilerInvalidates = compiler.artifact.drvPath != p.artifact.drvPath;
  headersInvalidate = headers.artifact.drvPath != p.artifact.drvPath;
  buildInvalidates = build.artifact.drvPath != p.artifact.drvPath;
  testFactoryRebound = runtime.tests.loader.package.drvPath == runtime.drvPath;
  upstreamRegistered =
    p.tests ? upstream
    && lib.hasInfix (builtins.unsafeDiscardStringContext upstream.outPath) (
      runs p.tests.upstream.buildSteps
    );
  independentUpstream =
    !(builtins.hasAttr (builtins.unsafeDiscardStringContext p.drvPath) upstreamContext)
    && !(builtins.hasAttr (builtins.unsafeDiscardStringContext p.artifact.drvPath) upstreamContext)
    &&
      names upstream.buildSteps == [
        "source.unpack"
        "llvm.configure"
        "llvm.build"
        "llvm.check"
      ];
  rawFailure = lib.hasInfix "exit 23" (
    runs (edit { upstreamCheck = "exit 23"; }).specification.upstreamPlan
  );
}

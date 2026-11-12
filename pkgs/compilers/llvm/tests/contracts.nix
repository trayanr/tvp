# Evaluation-only contracts: importing this file never requests LLVM outputs.
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
      rawGCC = alternate;
      gccRuntime = alternate;
      cxxRuntime = alternate;
      libc = alternate;
      targetBinutils = alternate;
      helperPython = alternate;
      patchelf = alternate;
      cmake = alternate;
      ninja = alternate;
      python = alternate;
      perl = alternate;
      zlib = alternate;
      zstd = alternate;
      libffi = alternate;
      libxml2 = alternate;
      bash = alternate;
      coreutils = alternate;
      sed = alternate;
      grep = alternate;
      diffutils = alternate;
    }
  );
  source = p.override { src = builtins.toFile "llvm-custom-source" "source fixture"; };
  base = p.edit (s: s // { base = s.base.override { name = "llvm-base-contract"; }; });
  runtime = p.editRuntime (r: r // { loader = "${alternate}/custom-loader"; });
in
{
  owned = s.base.name == "source-gnu-candidate" && !(p ? stdenv);
  profile = lib.all (f: builtins.elem f s.cmakeFlags) [
    "-DLLVM_ENABLE_PROJECTS=clang;lld"
    "-DLLVM_TARGETS_TO_BUILD=all"
    "-DLLVM_BUILD_LLVM_DYLIB=ON"
    "-DLLVM_LINK_LLVM_DYLIB=ON"
    "-DCLANG_LINK_CLANG_DYLIB=ON"
    "-DLLVM_ENABLE_RTTI=ON"
    "-DLLVM_ENABLE_ZLIB=FORCE_ON"
    "-DLLVM_ENABLE_ZSTD=FORCE_ON"
    "-DLLVM_ENABLE_LIBXML2=FORCE_ON"
    "-DLLVM_ENABLE_FFI=FORCE_ON"
    "-DLLVM_ENABLE_LIBEDIT=OFF"
    "-DLLVM_ENABLE_LIBPFM=OFF"
    "-DLLVM_ENABLE_Z3_SOLVER=OFF"
    "-DLLVM_INCLUDE_DOCS=OFF"
    "-DLLVM_INCLUDE_TESTS=OFF"
    "-DLLVM_INSTALL_UTILS=ON"
    "-DCLANG_DEFAULT_CXX_STDLIB=libstdc++"
    "-DCLANG_DEFAULT_RTLIB=libgcc"
  ];
  separateBuildCompiler = s.base.compiler.outPath != s.rawGCC.outPath;
  matchingRuntimes =
    s.rawGCC.outPath == s.cxxRuntime.outPath && s.rawGCC.outPath == s.gccRuntime.outPath;
  providers = lib.all (n: changed.tvp.deps.${n}.outPath == alternate.outPath) [
    "rawGCC"
    "gccRuntime"
    "cxxRuntime"
    "libc"
    "targetBinutils"
    "helperPython"
    "patchelf"
    "cmake"
    "ninja"
    "python"
    "perl"
    "zlib"
    "zstd"
    "libffi"
    "libxml2"
    "bash"
    "coreutils"
    "sed"
    "grep"
    "diffutils"
  ];
  discovery =
    has "${alternate}/bin/cmake" (run changed "llvm.configure")
    && has "${alternate}/bin/ninja" (run changed "llvm.configure")
    && has "-DZLIB_ROOT=${alternate}" (run changed "llvm.configure")
    && has "-DPython3_EXECUTABLE=${alternate}/bin/python3" (run changed "llvm.configure")
    && has "-DFFI_INCLUDE_DIR=${alternate}/include" (run changed "llvm.configure");
  wrapper =
    has "${alternate}/custom-loader" (run runtime "llvm.wrap-target")
    && has alternate (run changed "llvm.wrap-target");
  finalize =
    has "${alternate}/bin/patchelf" (run changed "output.rpaths")
    && has "${alternate}/bin/python3" (run changed "output.rpaths");
  installedScripts =
    has "${alternate}/bin/python3" (run changed "llvm.python-scripts")
    && has "${alternate}/bin/perl" (run changed "llvm.perl-scripts");
  upstream =
    has "test/Assembler" s.upstreamCheck
    && has "test/Bitcode" s.upstreamCheck
    && builtins.elem "-DLLVM_INCLUDE_TESTS=ON" s.upstreamCmakeFlags;
  upstreamTools =
    lib.all
      (
        name:
        let
          tool = lib.overrideDerivation s.${name} (old: {
            name = "${old.name}-llvm-upstream-tool-contract";
          });
          selected = p.edit (s: s // { ${name} = tool; });
          check = builtins.head (
            builtins.filter (x: x.name == "llvm.check") selected.specification.upstreamPlan
          );
        in
        selected.tvp.deps.${name}.drvPath == tool.drvPath
        && builtins.elem tool.drvPath (map (t: t.drvPath) check.tools)
      )
      [
        "sed"
        "grep"
        "diffutils"
      ];
  source = has "llvm-custom-source" (run source "source.unpack");
  tests =
    builtins.attrNames p.tests == [
      "aarch64-codegen"
      "c"
      "cxx"
      "ir"
      "linker"
      "loader"
      "preprocessor"
      "upstream"
      "version"
    ];
  rebound =
    changed.tests.version.package.drvPath == changed.drvPath
    && changed.tests.version.drvPath != p.tests.version.drvPath;
  runtimeTests =
    has "${alternate}/lib/libstdc++" (builtins.head changed.tests.cxx.buildSteps).run
    && has "${alternate}/lib/libgcc_s" (builtins.head changed.tests.cxx.buildSteps).run;
  loaderTest = has "${alternate}/custom-loader" (builtins.head runtime.tests.loader.buildSteps).run;
  baseTest = base.tests.version.specification.base.name == "llvm-base-contract";
  shellTest = changed.tests.version.specification.bash.outPath == alternate.outPath;
  runnerCoreutils = changed.specification.coreutils.outPath == alternate.outPath;
}

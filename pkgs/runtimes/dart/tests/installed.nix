{
  package,
  lib,
  context,
}:
let
  providers = package.specification.base.tools // {
    bash = package.specification.base.shell;
    coreutils = package.specification.base.coreutils;
    binutils = package.specification.base.compiler.bintools;
  };
  setup = ''export DART_SUPPRESS_ANALYTICS=true XDG_CONFIG_HOME="$PWD/config" PUB_CACHE="$PWD/cache"'';
in
context.mkSuite {
  inherit package;
  tools = [
    providers.coreutils
    package.specification.gawk
    providers.grep
    providers.sed
    providers.diffutils
    providers.binutils
  ];
  tests = {
    version = {
      script = "dart --version 2>&1 | awk '{print $4}' ";
      expected = package.version;
    };
    runtime = {
      script = ''
        for binary in .dart-unwrapped dartvm dartaotruntime; do
          test "$(patchelf --print-interpreter ${package}/bin/"$binary")" = '${package.tvp.dynamicLinker}'
        done
        dart pub --help > pub-help
        test -s pub-help
        printf matched
      '';
      expected = "matched";
      tools = ([
        providers.coreutils
        package.specification.gawk
        providers.grep
        providers.sed
        providers.diffutils
        providers.binutils
      ])
      ++ [ providers.patchelf ];
    };
    jit = {
      script = "${setup}; dart ${./fixtures/main.dart}";
      expected = "42";
    };
    aot = {
      script = "${setup}; dart compile exe ${./fixtures/main.dart} -o answer > compile.log; ./answer";
      expected = "42";
    };
    kernel = {
      script = "${setup}; dart compile kernel ${./fixtures/main.dart} -o answer.dill > compile.log; dart answer.dill";
      expected = "42";
    };
    javascript = {
      script = ''${setup}; dart compile js ${./fixtures/web.dart} -o answer.js > compile.log; node -e 'globalThis.self=globalThis;require(process.argv[1])' "$PWD/answer.js"'';
      expected = "42";
      tools = ([
        providers.coreutils
        package.specification.gawk
        providers.grep
        providers.sed
        providers.diffutils
        providers.binutils
      ])
      ++ [ package.tvp.declaredTestDependencies.nodejs ];
    };
    wasm = {
      script = "${setup}; dart compile wasm ${./fixtures/web.dart} -o answer.wasm > compile.log; test -s answer.wasm; test -s answer.mjs; printf compiled";
      expected = "compiled";
    };
    ffi = {
      script = ''${setup}; ${package.specification.llvm}/bin/clang -shared -fPIC ${./fixtures/answer.c} -o libanswer.so; dart ${./fixtures/ffi.dart} "$PWD/libanswer.so"'';
      expected = "42";
      tools = ([
        providers.coreutils
        package.specification.gawk
        providers.grep
        providers.sed
        providers.diffutils
        providers.binutils
      ])
      ++ [ package.specification.llvm ];
    };
    pub = {
      script = ''
        ${setup}
        mkdir -p bin answer/lib
        cp ${./fixtures/project/pubspec.yaml} pubspec.yaml
        cp ${./fixtures/project/bin/main.dart} bin/main.dart
        cp ${./fixtures/project/answer/pubspec.yaml} answer/pubspec.yaml
        cp ${./fixtures/project/answer/lib/answer.dart} answer/lib/answer.dart
        chmod -R u+w .
        dart pub get --offline > resolve.log
        dart analyze --fatal-infos > analyze.log
        dart run bin/main.dart
      '';
      expected = "42";
    };
  };
}

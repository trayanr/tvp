{
  pkgs,
  tvpLib,
  package,
  nodejs,
}:
let
  project = pkgs.lib.fileset.toSource {
    root = ./fixtures/project;
    fileset = pkgs.lib.fileset.unions [
      ./fixtures/project/pubspec.yaml
      ./fixtures/project/bin/main.dart
      ./fixtures/project/answer/pubspec.yaml
      ./fixtures/project/answer/lib/answer.dart
    ];
  };
  setup = ''export DART_SUPPRESS_ANALYTICS=true XDG_CONFIG_HOME="$PWD/config" PUB_CACHE="$PWD/cache"'';
in
tvpLib.tests.mkSuite {
  inherit pkgs package;
  tests = {
    version = {
      script = ''dart --version 2>&1 | awk '{print $4}' '';
      expected = package.version;
    };
    jit = {
      script = ''${setup}; dart ${./fixtures/main.dart}'';
      expected = "42";
    };
    aot = {
      script = ''${setup}; dart compile exe ${./fixtures/main.dart} -o answer > compile.log; ./answer'';
      expected = "42";
    };
    kernel = {
      script = ''${setup}; dart compile kernel ${./fixtures/main.dart} -o answer.dill > compile.log; dart answer.dill'';
      expected = "42";
    };
    javascript = {
      script = ''${setup}; dart compile js ${./fixtures/web.dart} -o answer.js > compile.log; node -e 'globalThis.self=globalThis;require(process.argv[1])' "$PWD/answer.js"'';
      expected = "42";
      extraInputs = [ nodejs ];
    };
    wasm = {
      script = ''${setup}; dart compile wasm ${./fixtures/web.dart} -o answer.wasm > compile.log; test -s answer.wasm; test -s answer.mjs; printf compiled'';
      expected = "compiled";
    };
    ffi = {
      script = ''${setup}; cc -shared -fPIC ${./fixtures/answer.c} -o libanswer.so; dart ${./fixtures/ffi.dart} "$PWD/libanswer.so"'';
      expected = "42";
      extraInputs = [ package.tvp.cc ];
    };
    pub = {
      script = ''
        ${setup}
        cp -r ${project}/. .
        chmod -R u+w .
        dart pub get --offline > resolve.log
        dart analyze --fatal-infos > analyze.log
        dart run bin/main.dart
      '';
      expected = "42";
    };
  };
}

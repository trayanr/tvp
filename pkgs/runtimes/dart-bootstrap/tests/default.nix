{
  pkgs,
  tvpLib,
  package,
}:
tvpLib.tests.mkSuite {
  inherit pkgs package;
  tests = {
    version = {
      script = ''dart --version 2>&1 | awk '{print $4}' '';
      expected = package.version;
    };
    compiler = {
      script = ''
        export DART_SUPPRESS_ANALYTICS=true XDG_CONFIG_HOME="$PWD/config" PUB_CACHE="$PWD/cache"
        cp ${./fixtures/main.dart} main.dart
        dart run main.dart > jit
        grep -x 42 jit >/dev/null
        dart compile exe main.dart -o answer > compile.log
        ./answer
      '';
      expected = "42";
    };
  };
}

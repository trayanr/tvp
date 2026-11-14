{
  package,
  lib,
  context,
}:
let
  providers = package.specification.base.standardTools // {
    bash = package.specification.base.shell;
    coreutils = package.specification.base.coreutils;
    binutils = package.specification.base.compiler.bintools;
  };
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

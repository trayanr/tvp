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
if !package.specification.testsEnabled then
  { }
else
  context.mkSuite {
    inherit package;
    tools = [
      providers.coreutils
      providers.sed
      providers.grep
    ];
    tests = {
      version = {
        script = ''export ANDROID_USER_HOME="$TMPDIR/android-user"; android --no-metrics --version > version.txt; grep -q '${package.version}' version.txt; printf cli-ok'';
        expected = "cli-ok";
      };
      help = {
        script = ''export ANDROID_USER_HOME="$TMPDIR/android-user"; android --no-metrics --help > help.txt; grep -q 'sdk' help.txt; printf sdk-cli'';
        expected = "sdk-cli";
      };
    };
  }

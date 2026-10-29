{
  pkgs,
  tvpLib,
  package,
}:
tvpLib.tests.mkSuite {
  inherit pkgs package;
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

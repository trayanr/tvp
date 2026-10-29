{
  pkgs,
  tvpLib,
  package,
}:
tvpLib.tests.mkSuite {
  inherit pkgs package;
  tests = {
    version = {
      script = ''sed -n 's/^Pkg.Revision=//p' ${package}/${package.tvp.android.componentPath}/source.properties'';
      expected = package.version;
    };
    cli = {
      script = ''export ANDROID_USER_HOME="$TMPDIR/android-user"; android --no-metrics --help > help.txt; grep -q 'sdk' help.txt; printf cli-ok'';
      expected = "cli-ok";
    };
  };
}

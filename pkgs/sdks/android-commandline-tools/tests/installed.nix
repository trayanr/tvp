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
    ] ++ [ package.specification.jdk ];
    tests = {
      version = {
        script = "sed -n 's/^Pkg.Revision=//p' ${package}/${package.tvp.android.componentPath}/source.properties";
        expected = package.version;
      };
      cli = {
        script = ''export ANDROID_USER_HOME="$TMPDIR/android-user"; android --no-metrics --help > help.txt; grep -q 'sdk' help.txt; printf cli-ok'';
        expected = "cli-ok";
      };
    };
  }

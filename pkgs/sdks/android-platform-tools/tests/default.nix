{
  pkgs,
  tvpLib,
  package,
}:
tvpLib.tests.mkSuite {
  inherit pkgs package;
  tests = {
    # adb initializes ~/.android even for --version, and has no configurable
    # home directory. Its native-host version check accompanies sandbox tests.
    revision = {
      script = ''sed -n 's/^Pkg.Revision=//p' ${package}/${package.tvp.android.componentPath}/source.properties'';
      expected = package.version;
    };
    fastboot = {
      script = ''fastboot --version | grep -q 'fastboot version'; printf fastboot-ok'';
      expected = "fastboot-ok";
    };
  };
}

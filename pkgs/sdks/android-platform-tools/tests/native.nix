{
  pkgs,
  tvpLib,
  package,
}:
if !package.specification.testsEnabled then
  { }
else
  package.testContext.mkSuite {
    inherit package;
    tools = with package.specification; [
      coreutils
      sed
      grep
    ];
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

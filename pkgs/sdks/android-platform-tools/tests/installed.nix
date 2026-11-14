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
      # adb initializes ~/.android even for --version, and has no configurable
      # home directory. Its native-host version check accompanies sandbox tests.
      revision = {
        script = "sed -n 's/^Pkg.Revision=//p' ${package}/${package.tvp.android.componentPath}/source.properties";
        expected = package.version;
      };
      fastboot = {
        script = "fastboot --version | grep -q 'fastboot version'; printf fastboot-ok";
        expected = "fastboot-ok";
      };
    };
  }

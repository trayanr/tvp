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
  jdk = package.tvp.declaredTestDependencies.jdk;
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
      api = {
        script = "sed -n 's/^AndroidVersion.ApiLevel=//p' ${package}/${package.tvp.android.componentPath}/source.properties";
        expected = package.tvp.android.apiLevel;
      };
      compile = {
        script = "cp ${./PlatformCheck.java} PlatformCheck.java; javac -source 8 -target 8 -bootclasspath ${package}/${package.tvp.android.componentPath}/android.jar PlatformCheck.java; javap -c PlatformCheck | grep -q 'android/os/Build'; printf platform-ok";
        expected = "platform-ok";
        tools = [
          providers.coreutils
          providers.sed
          providers.grep
          jdk
        ];
      };
    };
  }

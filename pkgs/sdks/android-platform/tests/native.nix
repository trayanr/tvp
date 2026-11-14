{
  pkgs,
  tvpLib,
  package,
}:
let
  jdk = package.tvp.declaredTestDependencies.jdk;
in
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
      api = {
        script = ''sed -n 's/^AndroidVersion.ApiLevel=//p' ${package}/${package.tvp.android.componentPath}/source.properties'';
        expected = package.tvp.android.apiLevel;
      };
      compile = {
        script = ''cp ${./PlatformCheck.java} PlatformCheck.java; javac -source 8 -target 8 -bootclasspath ${package}/${package.tvp.android.componentPath}/android.jar PlatformCheck.java; javap -c PlatformCheck | grep -q 'android/os/Build'; printf platform-ok'';
        expected = "platform-ok";
        tools = with package.specification; [
          coreutils
          sed
          grep
          jdk
        ];
      };
    };
  }

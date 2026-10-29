{
  pkgs,
  tvpLib,
  package,
  jdk,
}:
tvpLib.tests.mkSuite {
  inherit pkgs package;
  tests = {
    api = {
      script = ''sed -n 's/^AndroidVersion.ApiLevel=//p' ${package}/${package.tvp.android.componentPath}/source.properties'';
      expected = package.tvp.android.apiLevel;
    };
    compile = {
      script = ''cp ${./PlatformCheck.java} PlatformCheck.java; javac -source 8 -target 8 -bootclasspath ${package}/${package.tvp.android.componentPath}/android.jar PlatformCheck.java; javap -c PlatformCheck | grep -q 'android/os/Build'; printf platform-ok'';
      expected = "platform-ok";
      extraInputs = [ jdk ];
    };
  };
}

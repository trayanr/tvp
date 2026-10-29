{
  pkgs,
  tvpLib,
  package,
}:
tvpLib.tests.mkSuite {
  inherit pkgs package;
  tests = {
    version = {
      script = ''java -XshowSettings:properties -version 2>&1 | awk '$1=="java.version" {print $3}' '';
      expected = package.version;
    };
    runtime = {
      script = ''cp ${./fixtures/RuntimeCheck.java} RuntimeCheck.java; javac RuntimeCheck.java -d .; java -Djava.awt.headless=true RuntimeCheck'';
      expected = "runtime-ok";
    };
    native = {
      script = ''
        cp ${./fixtures/NativeCheck.java} NativeCheck.java
        javac -h . -d . NativeCheck.java
        cc -shared -fPIC -I${package}/include -I${package}/include/linux -I. ${./fixtures/native.c} -o libanswer.so
        java -Djava.library.path="$PWD" NativeCheck
      '';
      expected = "42";
      extraInputs = [ package.tvp.cc ];
    };
    shell = {
      script = ''cp ${./fixtures/ShellCheck.java} ShellCheck.java; javac ShellCheck.java -d .; export PATH="$PWD:$PATH"; java ShellCheck '${package.tvp.deps.bash}/bin/bash' '';
      expected = "shell-ok";
    };
    shell-fork = {
      script = ''cp ${./fixtures/ShellCheck.java} ShellCheck.java; javac ShellCheck.java -d .; export PATH="$PWD:$PATH"; java -Djdk.lang.Process.launchMechanism=FORK ShellCheck '${package.tvp.deps.bash}/bin/bash' '';
      expected = "shell-ok";
    };
    image = {
      script = ''
        cp ${./fixtures/NativeCheck.java} NativeCheck.java
        javac NativeCheck.java -d classes
        jar --create --file consumer.jar -C classes .
        jar --list --file consumer.jar | grep -q NativeCheck.class
        jlink --add-modules java.base,java.xml --strip-debug --no-man-pages --no-header-files --output image
        image/bin/java -XshowSettings:properties -version 2>&1 | awk '$1=="java.version" {print $3}'
      '';
      expected = package.version;
    };
  };
}

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
    compiler = {
      script = ''cp ${./fixtures/Hello.java} Hello.java; javac Hello.java -d .; java Hello'';
      expected = "42";
    };
  };
}

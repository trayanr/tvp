{
  pkgs,
  tvpLib,
  package,
}:
tvpLib.tests.mkSuite {
  inherit pkgs package;
  tests = {
    version = {
      script = ''go version | awk '{print $3}' '';
      expected = package.tvp.reportedVersion;
    };
    compile = {
      script = ''
        export GOPATH="$TMPDIR/work"
        go build -o hello ${./fixtures/hello.go}
        ./hello
      '';
      expected = "42";
    };
  };
}

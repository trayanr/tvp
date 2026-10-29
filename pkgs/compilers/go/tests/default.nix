{
  pkgs,
  tvpLib,
  package,
}:
let
  offlineSource = pkgs.lib.fileset.toSource {
    root = ./fixtures/offline;
    fileset = pkgs.lib.fileset.unions [
      ./fixtures/offline/go.mod
      ./fixtures/offline/main.go
      ./fixtures/offline/main_test.go
      ./fixtures/offline/helper/go.mod
      ./fixtures/offline/helper/helper.go
    ];
  };
  environment = ''
    unset CC CXX
    export GOCACHE="$TMPDIR/go-cache" GOPATH="$TMPDIR/go-work"
    export GOENV=off GOTOOLCHAIN=local GOPROXY=off GOSUMDB=off
  '';
in
tvpLib.tests.mkSuite {
  inherit pkgs package;
  tests =
    {
      version = {
        script = ''go version | awk '{print $3}' '';
        expected = "go${package.version}";
      };
      compiler-default = {
        script = environment + ''go env CC'';
        expected = "${package.tvp.cc}/bin/gcc";
      };
      modules = {
        script =
          environment
          + ''
            cp -r ${offlineSource} project
            chmod -R u+w project
            cd project
            go test ./... >&2
            go build -o app .
            ./app
          '';
        expected = "42";
      };
      compile = {
        script =
          environment
          + ''
            CGO_ENABLED=0 go build -o hello ${./fixtures/hello.go}
            ./hello
          '';
        expected = ''{"answer":42}'';
      };
      cgo = {
        script =
          environment
          + ''
            CGO_ENABLED=1 go build -o answer ${./fixtures/cgo.go}
            readelf -l answer | grep -F ${pkgs.lib.escapeShellArg package.tvp.dynamicLinker} >&2
            ldd answer | grep -F ${pkgs.lib.escapeShellArg "${package.tvp.cc.libc}/"} >&2
            ./answer
          '';
        expected = "42";
        extraInputs = [
          package.tvp.cc
          pkgs.glibc.bin
        ];
      };
      standard-library = {
        script =
          environment
          + ''
            go test bytes strings encoding/json math/big > tests.log 2>&1 || { cat tests.log >&2; exit 1; }
            cat tests.log >&2
            printf passed
          '';
        expected = "passed";
        extraInputs = [ package.tvp.cc ];
      };
    }
    // pkgs.lib.optionalAttrs package.tvp.features.toolchainSelection {
      toolchain-default = {
        script =
          environment
          + ''
            unset GOTOOLCHAIN
            go env GOTOOLCHAIN
          '';
        expected = "local";
      };
    };
}

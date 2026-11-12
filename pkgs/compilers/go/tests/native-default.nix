{ package }:
let
  s = package.specification;
  environment = ''
    unset CC CXX
    export GOCACHE="$TMPDIR/go-cache" GOPATH="$TMPDIR/go-work"
    export GOENV=off GOTOOLCHAIN=local GOPROXY=off GOSUMDB=off
  '';
in
(package.testContext.mkSuite {
  inherit package;
  tools = [
    s.coreutils
    s.grep
    s.binutils
    s.runtime.compiler
  ];
  tests = {
    version = {
      script = ''value=$(go version); printf '%s\n' "''${value#go version }" | { read -r version rest; printf '%s' "$version"; }'';
      expected = "go${package.version}";
    };
    compiler-default = {
      script = environment + ''test "$(go env CXX)" = "${s.runtime.cxx}"; go env CC'';
      expected = s.runtime.cc;
    };
    modules = {
      script =
        environment
        + ''
          cp -r ${./fixtures/offline} project
          chmod -R u+w project
          cd project
          go test ./... >&2
          go build -o app .
          ./app
        '';
      expected = "42";
    };
    compile = {
      script = environment + ''CGO_ENABLED=0 go build -o hello ${./fixtures/hello.go}; ./hello'';
      expected = ''{"answer":42}'';
    };
    cgo = {
      script =
        environment
        + ''
          CGO_ENABLED=1 go build -o answer ${./fixtures/cgo.go}
          ${s.binutils}/bin/readelf -l answer | grep -F '${s.runtime.loader}' >&2
          ${s.runtime.loader} --list ./answer | grep -F '${s.runtime.libc}/' >&2
          ./answer
        '';
      expected = "42";
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
    };
    toolchain-default = {
      script =
        environment
        + ''
          unset GOTOOLCHAIN
          test "$(go env GOTOOLCHAIN)" = local
          test "$(GOTOOLCHAIN=auto go env GOTOOLCHAIN)" = auto
          go env GOTOOLCHAIN
        '';
      expected = "local";
    };
  };
}) // { installed-environment = import ./installed-environment.nix { inherit package; }; }

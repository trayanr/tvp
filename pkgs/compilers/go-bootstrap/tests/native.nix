{ package }:
let
  s = package.specification;
  setup = ''
    export GOPATH="$TMPDIR/work"
    unset GOROOT
  '';
in
package.testContext.mkSuite {
  inherit package;
  tools = [
    s.coreutils
    s.grep
    s.binutils
    s.patchelf
  ];
  tests = {
    version = {
      script = ''value=$(go version); value="''${value#go version }"; printf '%s' "''${value%% *}"'';
      expected = package.tvp.reportedVersion;
    };
    compile = {
      script = setup + ''go build -o hello ${./fixtures/hello.go}; ./hello'';
      expected = "42";
    };
    formatting = {
      script = ''
        gofmt ${./fixtures/root.go} > formatted.go
        test -z "$(gofmt -l formatted.go)"
        test -s formatted.go
        printf formatted
      '';
      expected = "formatted";
    };
    cgo = {
      script = ''CGO_ENABLED=1 go env CGO_ENABLED'';
      expected = if package.tvp.features.cgo then "1" else "0";
    };
    nested-bootstrap = {
      script =
        setup
        + ''
          export GOROOT_BOOTSTRAP="${package}/share/go"
          export GOROOT="$TMPDIR/unrelated-next-stage-source"
          test "$("$GOROOT_BOOTSTRAP/bin/go" version)" = "$(go version)"
          test "$("$GOROOT_BOOTSTRAP/bin/go" env GOROOT)" = "$GOROOT_BOOTSTRAP"
          "$GOROOT_BOOTSTRAP/bin/go" build -o hello ${./fixtures/hello.go}
          ./hello
        '';
      expected = "42";
    };
    final-root = {
      script =
        setup
        + ''
            test "$(go env GOROOT)" = "${package}/share/go"
            test "$(go env GOTOOLDIR)" = "${package}/share/go/pkg/tool/${s.goOS}_${s.goArch}"
            test "$(go run ${./fixtures/root.go})" = "${package}/share/go"
          go build -o root ${./fixtures/root.go}
            # Go 1.4's supported runtime interface is the GOROOT environment;
            # next-stage processes inherit it from the nested launcher.
            GOROOT="$(go env GOROOT)" ./root
        '';
      expected = "${package}/share/go";
    };
    runtime-paths = {
      script = ''
        dist=${package}/share/go/pkg/tool/${s.goOS}_${s.goArch}/dist
        test "$(${s.patchelf}/bin/patchelf --print-interpreter "$dist")" = '${s.runtime.loader}'
        test "$(${s.patchelf}/bin/patchelf --print-rpath "$dist")" = '${s.runtime.libc}/lib'
        ${s.runtime.loader} --list "$dist" > libraries
        grep -F '${s.runtime.libc}/lib/libc.so.6' libraries >&2
        printf selected-runtime
      '';
      expected = "selected-runtime";
    };
    source-build-interface = {
      script = ''
        test "$(head -n 1 ${package}/nix-support/c-build-providers)" = "${s.compiler}/bin/cc"
        test "$(tail -n 1 ${package}/nix-support/c-build-providers)" = "${s.compiler.bintools}/bin/ld"
        test "$(head -n 1 ${package}/nix-support/build-options)" = "${s.cStandard}"
        test "$(tail -n 1 ${package}/nix-support/build-options)" = "${s.compiledRoot}"
        test "$(head -n 1 ${package}/share/go/bin/go)" = '#!${s.runtime.shell}/bin/bash'
        test "$(go env GOOS)" = '${s.goOS}'
        test "$(go env GOARCH)" = '${s.goArch}'
        test -f ${package}/share/go/pkg/${s.goOS}_${s.goArch}/runtime.a
        test -d ${package}/share/go/src/runtime
        printf source-c
      '';
      expected = "source-c";
    };
  };
}

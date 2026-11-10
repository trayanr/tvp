# The 20171003 C-source snapshot needs no earlier Go compiler. Keep its
# retained complete procedure alongside this independent native implementation.
{
  tvp,
  lib,
  base,
  src,
  version,
  compiler,
  bash,
  coreutils,
  gnutar,
  gzip,
  findutils,
  grep,
  sed,
  helperPython,
  binutils,
  patchelf,
  runtimeShell,
  runtimeLibc,
  cStandard,
  goOS,
  goArch,
  reportedVersion,
  compiledRoot,
  cgo,
}:
final:
let
  inherit (tvp.builder) steps outputs;
  environment = (final.base.override { compiler = final.compiler; }).environment final.environment;
  command =
    name: run:
    environment
    // {
      name = "go-bootstrap.${name}";
      cwd = "source";
      inherit run;
    };
  paths = [
    "share/go/bin"
    "share/go/pkg/tool"
  ];
in
{
  pname = "go-bootstrap";
  base = base.override { compiler = final.compiler; };
  inherit
    src
    version
    compiler
    bash
    coreutils
    gnutar
    gzip
    findutils
    grep
    sed
    helperPython
    binutils
    patchelf
    runtimeShell
    runtimeLibc
    cStandard
    goOS
    goArch
    reportedVersion
    compiledRoot
    cgo
    ;
  environment = {
    tools = [
      final.bash
      final.coreutils
      final.grep
      final.sed
    ];
    libraries = [ ];
    overrides.flags.NIX_CFLAGS_COMPILE = [ "-std=${final.cStandard}" ];
  };
  runtime = {
    shell = final.runtimeShell;
    libc = final.runtimeLibc;
    loader = "${final.runtime.libc}/lib/ld-linux-x86-64.so.2";
    libraries = [ final.runtime.libc ];
  };
  dependencyProviders = {
    runtimeShell = final.runtime.shell;
    runtimeLibc = final.runtime.libc;
  };
  plan =
    assert !final.cgo || throw "The C-source bootstrap supports only CGO_ENABLED=0";
    assert final.goOS == "linux" && final.goArch == "amd64";
    assert lib.hasPrefix "/" final.compiledRoot && !(lib.hasInfix "/nix/store/" final.compiledRoot);
    steps.sequence [
      (steps.unpack {
        inherit (final) src gzip findutils;
        tar = final.gnutar;
        compression = "gzip";
      })
      (command "build" ''
        test "$(cat VERSION)" = ${lib.escapeShellArg final.reportedVersion}
        export GOOS=${lib.escapeShellArg final.goOS} GOARCH=${lib.escapeShellArg final.goArch}
        export CGO_ENABLED=0 CC=${lib.escapeShellArg environment.env.CC}
        export GOROOT="$PWD" GOROOT_FINAL=${lib.escapeShellArg final.compiledRoot}
        cd src
        ${final.bash}/bin/bash ./make.bash
      '')
      (command "install-raw" ''
        mkdir -p "$out/share/go" "$out/bin" "$out/nix-support"
        cp -a . "$out/share/go/"
        printf '%s\n' ${lib.escapeShellArg environment.env.CC} ${lib.escapeShellArg environment.env.LD} > "$out/nix-support/c-build-providers"
        printf '%s\n' ${lib.escapeShellArg final.cStandard} ${lib.escapeShellArg final.compiledRoot} > "$out/nix-support/build-options"
      '')
      (steps.split "go-bootstrap.finalize")
      (outputs.copyArtifacts { inherit (final) coreutils; })
      # Compile against a stable non-store root, then bind the actual root in
      # BOTH interfaces. Next-stage make.bash calls share/go/bin/go directly
      # with its own GOROOT set: this launcher deliberately replaces that value.
      # Programs querying runtime.GOROOT must run with GOROOT from `go env GOROOT`;
      # an arbitrary standalone program retains Go 1.4's compiled-root fallback.
      {
        name = "go-bootstrap.launchers";
        tools = [ final.coreutils ];
        run = ''
          mv "$out/share/go/bin/go" "$out/share/go/bin/go-unwrapped"
          cat > "$out/share/go/bin/go" <<EOF
          #!${final.runtime.shell}/bin/bash
          export GOROOT="$out/share/go"
          export CGO_ENABLED=0
          exec "$out/share/go/bin/go-unwrapped" "\$@"
          EOF
          chmod +x "$out/share/go/bin/go"
          ln -s ../share/go/bin/go "$out/bin/go"
          ln -s ../share/go/bin/gofmt "$out/bin/gofmt"
        '';
      }
      (outputs.interpreters {
        python = final.helperPython;
        inherit (final) binutils patchelf;
        inherit paths;
        inherit (final.runtime) loader;
      })
      (outputs.rpaths {
        python = final.helperPython;
        inherit (final) binutils patchelf;
        inherit paths;
        inherit (final.runtime) libraries;
      })
      (outputs.checkPaths {
        python = final.helperPython;
        inherit (final) binutils patchelf;
        inherit paths;
      })
      (outputs.checkSymlinkTree {
        python = final.helperPython;
        paths = [ "bin" ];
      })
    ];
  tvp.reportedVersion = final.reportedVersion;
  tvp.features.cgo = final.cgo;
  tvp.dynamicLinker = final.runtime.loader;
  tvp.runtimeProviders = final.runtime;
  meta = {
    description = "Upstream C-based Go bootstrap compiler distribution";
    homepage = "https://go.dev/doc/install/source";
    license = lib.licenses.bsd3;
    platforms = [ "x86_64-linux" ];
    mainProgram = "go";
  };
}

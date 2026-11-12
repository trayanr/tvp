# Go 1.22/1.24: go.env source boundary; 1.24 removed GOROOT_FINAL.
{
  tvp,
  doCheck ? false,
  lib,
  base,
  src,
  version,
  bash,
  coreutils,
  helperPython,
  gnutar,
  gzip,
  findutils,
  binutils,
  patchelf,
  grep,
  sed,
  bootstrap,
  goOS,
  goArch,
  dynamicLinker,
}@args:
final:
let
  inherit (final)
    base
    src
    version
    bash
    coreutils
    helperPython
    gnutar
    gzip
    findutils
    binutils
    patchelf
    grep
    sed
    bootstrap
    goOS
    goArch
    dynamicLinker
    ;
  inherit (tvp.builder) steps outputs;
  runtimeCompiler =
    if final.runtime.compiler ? libc && final.runtime.compiler ? bintools then
      final.runtime.compiler
    else
      throw "Go runtime.compiler requires a compiler driver with libc and bintools; adapt raw compilers before selecting them";
  environment =
    if final.runtime.libc.outPath != runtimeCompiler.libc.outPath then
      throw "Go runtime.libc must match runtime.compiler.libc; select a coherent compiler driver"
    else if !(lib.hasPrefix "${final.runtime.libc}/" final.runtime.loader) then
      throw "Go runtime.loader must belong to the selected runtime.libc"
    else
      (base.override { compiler = runtimeCompiler; }).environment final.environment;
  command =
    name: run:
    environment
    // {
      name = "go.${name}";
      cwd = "source";
      run = ''
        export GOOS=${lib.escapeShellArg goOS} GOARCH=${lib.escapeShellArg goArch}
        export GO_LDSO=${lib.escapeShellArg final.runtime.loader} CGO_ENABLED=1
        export GOENV=off GOTOOLCHAIN=local GOPROXY=off GOSUMDB=off
        export GOCACHE="$TMPDIR/go-cache" GOPATH="$TMPDIR/go-work"
        mkdir -p "$NIX_BUILD_TOP/evidence"
        ${run}
      '';
    };
in
{
  pname = "go";
  upstreamArguments = [ "-rebuild" ];
  upstreamFactory = ../tests/upstream-ordinary.nix;
  passthru = package: {
    validation =
      (import final.upstreamFactory {
        inherit tvp lib;
        package = package // {
          specification = final;
        };
      }).execution;
  };
  inherit (args)
    base
    src
    version
    bash
    coreutils
    helperPython
    gnutar
    gzip
    findutils
    binutils
    patchelf
    grep
    sed
    bootstrap
    goOS
    goArch
    dynamicLinker
    ;
  # The build and installed default C/C++ compilers are the effective owned
  # environment bindings. No stdenv or executable-name discovery participates.
  environment = {
    tools = [
      bash
      coreutils
      grep
      sed
    ];
    libraries = [ ];
  };
  runtime = {
    shell = bash;
    toolchain = "local";
    compiler = base.compiler;
    libc = runtimeCompiler.libc;
    loader = "${final.runtime.libc}/${dynamicLinker}";
    cc = environment.env.CC;
    cxx = environment.env.CXX;
  };
  plan = steps.sequence [
    (steps.unpack {
      src = final.src;
      tar = gnutar;
      inherit gzip findutils;
      compression = "gzip";
    })
    (command "build" ''
      export CC=${lib.escapeShellArg final.runtime.cc} CXX=${lib.escapeShellArg final.runtime.cxx}
      export GOROOT="$PWD"
      # Stable compile-time fallback; cmd/go discovers the installed tree from
      # os.Executable. Never bake the artifact or final store path into Go IDs.
      ${lib.optionalString (lib.versionOlder version "1.24") "export GOROOT_FINAL=/tvp/go"}
      export GOROOT_BOOTSTRAP="${bootstrap}/share/go"
      printf '%s\n' "$CC" "$CXX" "$GO_LDSO" "$GOROOT_BOOTSTRAP" > "$NIX_BUILD_TOP/evidence/build-providers"
      cd src
      ${bash}/bin/bash ./make.bash
    '')
    (command "install" ''
      mkdir -p "$out/share/go" "$out/bin" "$out/nix-support"
      cp -a . "$out/share/go/"
      ln -s ../share/go/bin/go "$out/bin/go"
      ln -s ../share/go/bin/gofmt "$out/bin/gofmt"
      cp "$NIX_BUILD_TOP/evidence/build-providers" "$out/nix-support/build-providers"
      cp "$TVP_SOURCE_ROOT/source-date-epoch" "$out/nix-support/source-date-epoch"
    '')
    (steps.split "go.finalize")
    (outputs.copyArtifacts { inherit coreutils; })
    {
      name = "go.installed-toolchain";
      tools = [ helperPython ];
      run = ''
        ${helperPython}/bin/python3 -B - "$out/share/go/go.env" ${lib.escapeShellArg final.runtime.toolchain} <<'PYTHON'
        from pathlib import Path
        import sys
        p = Path(sys.argv[1])
        text = p.read_text()
        assert text.count('GOTOOLCHAIN=auto') == 1
        assert sys.argv[2] in ('local', 'auto')
        p.write_text(text.replace('GOTOOLCHAIN=auto', 'GOTOOLCHAIN=' + sys.argv[2]))
        PYTHON
      '';
    }
    (outputs.shebangs {
      python = helperPython;
      paths = [
        "share/go/src"
        "share/go/misc"
      ];
      names = [
        "sh"
        "bash"
      ];
      interpreter = "${final.runtime.shell}/bin/bash";
    })
    (outputs.interpreters {
      python = helperPython;
      inherit binutils patchelf;
      paths = [
        "share/go/bin"
        "share/go/pkg/tool"
      ];
      loader = final.runtime.loader;
    })
    # Go's compiler tools carry Go build IDs/symbols. Preserve those bytes;
    # validate ELF paths without treating source testdata as installed programs.
    (outputs.checkPaths {
      python = helperPython;
      inherit binutils patchelf;
      paths = [
        "share/go/bin"
        "share/go/pkg/tool"
      ];
    })
  ];
  tvp.dynamicLinker = final.runtime.loader;
  tvp.cc = runtimeCompiler;
  tvp.features = {
    cgo = true;
    toolchainSelection = true;
  };
  meta = {
    description = "Go compiler and standard library built from source";
    homepage = "https://go.dev/";
    license = lib.licenses.bsd3;
    platforms = [ "x86_64-linux" ];
    mainProgram = "go";
  };
}

# Go 1.27.3 starts the direct native procedure; the retained 1.24.13 seed
# constructs it without changing any older bootstrap generation.
{
  tvp,
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
  environment = base.environment final.environment;
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
    compiler = base.compiler;
    libc = base.compiler.libc;
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
    (command "prepare" ''
      ${helperPython}/bin/python3 -B - <<'PY'
      from pathlib import Path
      p = Path('go.env')
      text = p.read_text()
      assert text.count('GOTOOLCHAIN=auto') == 1
      p.write_text(text.replace('GOTOOLCHAIN=auto', 'GOTOOLCHAIN=local'))
      PY
    '')
    (command "build" ''
      export CC=${lib.escapeShellArg final.runtime.cc} CXX=${lib.escapeShellArg final.runtime.cxx}
      export GOROOT="$PWD" GOROOT_FINAL="$out/share/go"
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
      GOENV=off "$out/bin/go" env -json > "$out/nix-support/installed-environment.json"
    '')
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

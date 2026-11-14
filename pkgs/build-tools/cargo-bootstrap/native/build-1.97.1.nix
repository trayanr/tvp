# 1.97.1: pinned upstream binary repack, never a source bootstrap claim.
# Install the pristine payload before the split; host adaptation is final-only.
{
  tvp,
  lib,
  base,
  src,
  version,
  bash,
  coreutils,
  python,
  binutils,
  patchelf,
  tar,
  gzip,
  sed,
  grep,
  gawk,
  findutils,
  runtimeLibc,
  runtimeCompiler,
}:
final:
let
  inherit (tvp.builder) steps outputs;
in
{
  pname = "cargo-bootstrap";
  inherit
    base
    src
    version
    bash
    coreutils
    python
    binutils
    patchelf
    tar
    gzip
    sed
    grep
    gawk
    findutils
    runtimeLibc
    runtimeCompiler
    ;
  runtime = {
    libc = final.runtimeLibc;
    compiler = final.runtimeCompiler;

    loader = "${final.runtime.libc}/lib/ld-linux-x86-64.so.2";
    libraries = [
      final.runtime.libc
      final.runtime.compiler
    ];
    shell = final.bash;
  };
  dependencyProviders = {

    runtimeLibc = final.runtime.libc;
    runtimeCompiler = final.runtime.compiler;
  };
  environment = {
    tools = [
      final.coreutils
      final.tar
      final.gzip
      final.sed
      final.grep
      final.gawk
      final.findutils
    ];
    libraries = [ ];
  };
  plan = steps.sequence [
    (
      (final.base.environment final.environment)
      // {
        name = "cargo-bootstrap.install-pristine";
        run = ''
                 mkdir source
                 ${final.tar}/bin/tar -xf ${lib.escapeShellArg (toString final.src)} --strip-components=1 -C source
                 mkdir "$out"
          cp -a source/cargo/bin source/cargo/etc source/cargo/share "$out/"
        '';
      }
    )
    (steps.split "cargo-bootstrap.finalize")
    (outputs.copyArtifacts { inherit (final) coreutils; })
    (outputs.hostELF {
      python = final.python;
      inherit (final) binutils patchelf;
      paths = [ "bin" ];
      inherit (final.runtime) loader libraries;
    })
    (outputs.shebangs {
      inherit (final) python;
      paths = [
        "bin"
        "etc"
      ];
      names = [
        "sh"
        "bash"
      ];
      interpreter = "${final.runtime.shell}/bin/bash";
    })

    {
      name = "cargo-bootstrap.startup";
      tools = [ final.coreutils ];
      run = ''
        "$out/bin/cargo" --version
      '';
    }
  ];
  tvp.cc = final.base.compiler;
  tvp.dynamicLinker = final.runtime.loader;
  tvp.targetRuntime = final.runtime.libraries;
  tvp.runtimeProviders = final.runtime;

  meta = {
    description = "Explicit binary Cargo bootstrap from the upstream Rust distribution";
    homepage = "https://www.rust-lang.org/";
    license = [
      lib.licenses.mit
      lib.licenses.asl20
    ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "cargo";
  };
}

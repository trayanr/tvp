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
  zlib,
}:
final:
let
  inherit (tvp.builder) steps outputs;
in
{
  pname = "rustc";
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
    zlib
    ;
  runtime = {
    libc = final.runtimeLibc;
    compiler = final.runtimeCompiler;
    zlib = final.zlib;
    loader = "${final.runtime.libc}/lib/ld-linux-x86-64.so.2";
    libraries = [
      final.runtime.libc
      final.runtime.compiler
      final.runtime.zlib
    ];
    shell = final.bash;
  };
  dependencyProviders = {

    runtimeLibc = final.runtime.libc;
    runtimeCompiler = final.runtime.compiler;
    zlib = final.runtime.zlib;
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
        name = "rustc.install-pristine";
        run = ''
                 mkdir source
                 ${final.tar}/bin/tar -xf ${lib.escapeShellArg (toString final.src)} --strip-components=1 -C source
                 cd source
          ${final.bash}/bin/bash ./install.sh --prefix="$out" --components=rustc,rust-std-x86_64-unknown-linux-gnu --disable-ldconfig
        '';
      }
    )
    (steps.split "rustc.finalize")
    (outputs.copyArtifacts { inherit (final) coreutils; })
    {
      name = "rustc.validate-host-roles";
      tools = [ final.python ];
      run = ''${final.python}/bin/python3 -B ${./host-inventory.py} "$out"'';
    }
    (outputs.hostELF {
      python = final.python;
      inherit (final) binutils patchelf;
      paths = [
        "bin"
        "libexec"
        "lib/rustlib/x86_64-unknown-linux-gnu/bin"
        "lib/rustlib/x86_64-unknown-linux-gnu/bin/gcc-ld"
      ];
      inherit (final.runtime) loader libraries;
    })
    {
      name = "rustc.host-self-runtime";
      tools = [
        final.python
        final.binutils
        final.patchelf
      ];
      run = ''${final.python}/bin/python3 -B ${../../../../lib/append-self-rpaths.py} "$out" ${
        lib.escapeShellArg (
          builtins.toJSON {
            paths = [
              "bin"
              "libexec"
              "lib/rustlib/x86_64-unknown-linux-gnu/bin"
            ];
            directories = [ "lib" ];
            readelf = "${final.binutils}/bin/readelf";
            patchelf = "${final.patchelf}/bin/patchelf";
          }
        )
      } ${../../../../lib/native-output}'';
    }
    # Preserve BOLT host-library symbols and use their existing self RPATH.
    {
      name = "rustc.host-library-runtime";
      tools = [
        final.python
        final.binutils
        final.patchelf
      ];
      run = ''${final.python}/bin/python3 -B ${./link-host-runtime.py} "$out" ${
        lib.escapeShellArg (
          builtins.toJSON {
            libraries = map (p: "${lib.getLib p}/lib") final.runtime.libraries;
            readelf = "${final.binutils}/bin/readelf";
            patchelf = "${final.patchelf}/bin/patchelf";
          }
        )
      } ${../../../../lib/native-output}'';
    }
    # The installer writes absolute paths only in these named text records.
    (outputs.relocateText {
      inherit (final) python;
      paths = [
        "lib/rustlib/manifest-rustc"
        "lib/rustlib/manifest-rust-std-x86_64-unknown-linux-gnu"
        "lib/rustlib/install.log"
        "lib/rustlib/uninstall.sh"
      ];
    })
    (outputs.shebangs {
      inherit (final) python;
      paths = [
        "bin"
        "lib/rustlib/uninstall.sh"
      ];
      names = [
        "sh"
        "bash"
      ];
      interpreter = "${final.runtime.shell}/bin/bash";
    })

    {
      name = "rustc.startup";
      tools = [ final.coreutils ];
      run = ''
               "$out/bin/rustc" --version
        "$out/bin/rustdoc" --version
      '';
    }
  ];
  tvp.cc = final.base.compiler;
  tvp.dynamicLinker = final.runtime.loader;
  tvp.targetRuntime = final.runtime.libraries;
  tvp.runtimeProviders = final.runtime;

  meta = {
    description = "The Rust compiler (upstream binary seed)";
    homepage = "https://www.rust-lang.org/";
    license = [
      lib.licenses.mit
      lib.licenses.asl20
    ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "rustc";
  };
}

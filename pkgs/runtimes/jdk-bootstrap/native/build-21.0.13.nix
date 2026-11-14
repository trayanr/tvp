# 21.0.13: pinned upstream binary repack, never a source bootstrap claim.
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
  alsa,
  fontconfig,
}:
final:
let
  inherit (tvp.builder) steps outputs;
in
{
  pname = "jdk-bootstrap";
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
    alsa
    fontconfig
    ;
  runtime = {
    libc = final.runtimeLibc;
    compiler = final.runtimeCompiler;
    zlib = final.zlib;
    alsa = final.alsa;
    fontconfig = final.fontconfig;
    loader = "${final.runtime.libc}/lib/ld-linux-x86-64.so.2";
    libraries = [
      final.runtime.libc
      final.runtime.compiler
      final.runtime.zlib
      final.runtime.alsa
      final.runtime.fontconfig
    ];
  };
  dependencyProviders = {

    runtimeLibc = final.runtime.libc;
    runtimeCompiler = final.runtime.compiler;
    zlib = final.runtime.zlib;
    alsa = final.runtime.alsa;
    fontconfig = final.runtime.fontconfig;
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
        name = "jdk-bootstrap.install-pristine";
        run = ''
                 mkdir source
                 ${final.tar}/bin/tar -xf ${lib.escapeShellArg (toString final.src)} --strip-components=1 -C source
                 mkdir "$out"
          cp -a source/. "$out/"
          # The pinned seed exposes the headless interface only.
          rm -f "$out/lib/libawt_xawt.so"
        '';
      }
    )
    (steps.split "jdk-bootstrap.finalize")
    (outputs.copyArtifacts {
      inherit (final) coreutils;
      preserveHardlinks = false;
    })
    (outputs.interpreters {
      inherit (final) python binutils patchelf;
      paths = [
        "bin"
        "lib"
      ];
      inherit (final.runtime) loader;
    })
    (outputs.rpaths {
      inherit (final) python binutils patchelf;
      paths = [
        "bin"
        "lib"
      ];
      inherit (final.runtime) libraries;
    })
    {
      name = "jdk-bootstrap.self-runtime";
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
              "lib"
            ];
            directories = [
              "lib"
              "lib/server"
            ];
            readelf = "${final.binutils}/bin/readelf";
            patchelf = "${final.patchelf}/bin/patchelf";
          }
        )
      } ${../../../../lib/native-output}'';
    }

    {
      name = "jdk-bootstrap.startup";
      tools = [ final.coreutils ];
      run = ''
               "$out/bin/java" -Djava.awt.headless=true -version
        "$out/bin/javac" -version
      '';
    }
  ];
  tvp.cc = final.base.compiler;
  tvp.dynamicLinker = final.runtime.loader;
  tvp.targetRuntime = final.runtime.libraries;
  tvp.runtimeProviders = final.runtime;
  tvp.features.gui = false;
  meta = {
    description = "Explicit headless Temurin boot JDK seed";
    homepage = "https://adoptium.net/";
    license = lib.licenses.gpl2Classpath;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "java";
  };
}

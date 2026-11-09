# Ordinary 21.0.13: explicit owned construction and pre-module ELF cleanup.
# The retained legacy recipe independently serves frozen construction callers.
{
  tvp,
  lib,
  base,
  src,
  version,
  patches,
  buildNumber,
  dynamicLinker,
  bash,
  coreutils,
  gnumake,
  gnutar,
  gzip,
  xz,
  bzip2,
  patch,
  findutils,
  sed,
  grep,
  gawk,
  diffutils,
  which,
  python,
  perl,
  binutils,
  bootJdk,
  autoconf,
  zip,
  unzip,
  file,
  pkg-config,
  patchelf,
  zlib,
  alsa,
  freetype,
  fontconfig,
  libcups,
  xorgproto,
  libx11,
  libxext,
  libxrender,
  libxtst,
  libxrandr,
  libxt,
  configurationName ? "tvp-release",
  imageDirectory ? "images/jdk",
}:
final:
let
  inherit (tvp.builder) steps outputs;
  command =
    name: run:
    (final.base.environment final.environment)
    // {
      name = "jdk.${name}";
      cwd = "source";
      inherit run;
    };
  make = ''${final.gnumake}/bin/make -j"$NIX_BUILD_CORES" CONF=${lib.escapeShellArg final.configurationName} SHELL=${final.bash}/bin/bash'';
  outputPaths = [
    "bin"
    "lib"
  ];
in
{
  pname = "jdk";
  inherit
    base
    src
    version
    patches
    buildNumber
    dynamicLinker
    configurationName
    imageDirectory
    bash
    coreutils
    gnumake
    gnutar
    gzip
    xz
    bzip2
    patch
    findutils
    sed
    grep
    gawk
    diffutils
    which
    python
    perl
    binutils
    bootJdk
    autoconf
    zip
    unzip
    file
    pkg-config
    patchelf
    zlib
    alsa
    freetype
    fontconfig
    libcups
    xorgproto
    libx11
    libxext
    libxrender
    libxtst
    libxrandr
    libxt
    ;
  environment = {
    tools = [
      final.bash
      final.coreutils
      final.gnumake
      final.gnutar
      final.gzip
      final.xz
      final.bzip2
      final.patch
      final.findutils
      final.sed
      final.grep
      final.gawk
      final.diffutils
      final.which
      final.python
      final.perl
      final.binutils
      final.bootJdk
      final.autoconf
      final.zip
      final.unzip
      final.file
      final.pkg-config
      final.patchelf
    ];
    libraries = [
      final.xorgproto
      final.libx11
      final.libxext
      final.libxrender
      final.libxtst
      final.libxrandr
      final.libxt
      final.zlib
      final.alsa
      final.freetype
      final.fontconfig
      final.libcups
    ];
  };
  runtime.libraries = [
    final.zlib
    final.alsa
    final.freetype
    final.fontconfig
    final.libcups
  ];
  plan = steps.sequence [
    (steps.unpack {
      src = final.src;
      tar = final.gnutar;
      gzip = final.gzip;
      compression = "gzip";
      findutils = final.findutils;
    })
    (command "patch" ''
      ${lib.concatMapStringsSep "\n" (p: "${final.patch}/bin/patch -p1 < ${p}") final.patches}
      ${final.python}/bin/python3 -B ${./source-paths.py} \
        ${lib.escapeShellArg "${final.bash}/bin/bash"} \
        ${lib.escapeShellArg "${final.fontconfig}/lib/libfontconfig.so"}
    '')
    (command "configure" ''
      export CONFIG_SHELL=${final.bash}/bin/bash
      ${final.bash}/bin/bash configure \
        --with-conf-name=${lib.escapeShellArg final.configurationName} \
        --prefix="$out" --with-boot-jdk=${lib.escapeShellArg (toString final.bootJdk)} \
        --x-includes=${final.libx11}/include --x-libraries=${final.libx11}/lib \
        --with-debug-level=release --with-jvm-variants=server --enable-headless-only \
        --with-freetype=system --with-freetype-include=${final.freetype}/include/freetype2 --with-freetype-lib=${final.freetype}/lib \
        --with-fontconfig=${final.fontconfig} --with-cups=${final.libcups} --with-alsa=${final.alsa} --with-zlib=system \
        --with-version-pre= --with-version-opt= --with-version-build=${lib.escapeShellArg final.buildNumber} \
        --with-native-debug-symbols=none --with-jobs="$NIX_BUILD_CORES" \
        --disable-warnings-as-errors
    '')
    (command "exploded-image" "${make} exploded-image")
    (
      (outputs.rpaths {
        workspaceRoot = "source/build/${final.configurationName}";
        # Images also package the separate support originals into JMOD payloads.
        paths = [
          "jdk"
          "support/modules_libs"
          "support/modules_cmds"
        ];
        elfKinds = [ "runtime" ];
        inherit (final) python binutils patchelf;
        dlopenDirectories = [ "${final.libcups}/lib" ];
      })
      // {
        name = "jdk.pre-image-rpaths";
      }
    )
    (command "images" "${make} images")
    (command "install" ''
      mkdir -p "$out"
      cp -a build/${lib.escapeShellArg final.configurationName}/${lib.escapeShellArg final.imageDirectory}/. "$out/"
      mkdir -p "$out/nix-support"
      cp "$TVP_SOURCE_ROOT/source-date-epoch" "$out/nix-support/source-date-epoch"
    '')
    {
      name = "jdk.installed-loaders-and-self-paths";
      tools = [
        final.python
        final.binutils
        final.patchelf
      ];
      run = ''${final.python}/bin/python3 -B ${./interpreters.py} "$out" ${
        lib.escapeShellArg (
          builtins.toJSON {
            paths = outputPaths;
            readelf = "${final.binutils}/bin/readelf";
            patchelf = "${final.patchelf}/bin/patchelf";
            interpreter = "${final.base.compiler.libc}/${final.dynamicLinker}";
          }
        )
      } ${../../../../lib/native-output}'';
    }
    (outputs.rpaths {
      inherit (final)
        python
        binutils
        patchelf
        base
        ;
      paths = outputPaths;
      libraries = final.runtime.libraries;
      dlopenDirectories = [ "${final.libcups}/lib" ];
    })
    (outputs.strip {
      inherit (final) python binutils;
      paths = outputPaths;
    })
    (outputs.checkPaths {
      inherit (final) python binutils patchelf;
      paths = outputPaths;
    })
  ];
  tvp = {
    features = {
      gui = false;
      trimmedRuntime = true;
    };
    runtimeForbiddenReferences = [
      final.bootJdk
      final.file
      final.xorgproto
      final.libx11
      final.libxext
      final.libxrender
      final.libxtst
      final.libxrandr
      final.libxt
    ];
    bootstrapBoundary = "TEMURIN BINARY SEED: constrained jdk-bootstrap_21_0_13; source bootstrap remains blocked.package=jdk-bootstrap-from-source";
  };
  meta = {
    description = "Source-built headless OpenJDK development kit";
    homepage = "https://openjdk.org/";
    license = lib.licenses.gpl2Classpath;
    platforms = [ "x86_64-linux" ];
    mainProgram = "java";
  };
}

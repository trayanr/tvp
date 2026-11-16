# Independent GCC 4.9.4 C/C++ source procedure, built with the earlier owned
# compiler. Upstream/installed tests are consumers, not compilation prerequisites.
{
  tvp,
  lib,
  base,
  src,
  version,
  glibc,
  binutils,
  gmp,
  mpfr,
  mpc,
  zlib,
  texinfo,
  perl,
  file,
  which,
}:
final:
let
  context = tvp.builder.forBase final.base;
  inherit (context) steps outputs tools;
  libc = final.glibc;
  shell = "${tools.bash}/bin/bash";
  includes = "-B${libc}/lib/ -idirafter ${lib.getDev libc}/include -I${lib.getDev final.zlib}/include";
  links =
    "-Wl,-dynamic-linker,${libc}/lib/ld-linux-x86-64.so.2 -Wl,-rpath,$out/lib "
    + lib.concatMapStringsSep " " (p: "-L${lib.getLib p}/lib -Wl,-rpath,${lib.getLib p}/lib") [
      libc
      final.gmp
      final.mpfr
      final.mpc
      final.zlib
    ];
  command =
    name: run:
    (final.base.environment final.environment)
    // {
      name = "gcc.${name}";
      cwd = "build";
      run = ''
        export CONFIG_SHELL=${shell} SHELL=${shell}
        export CFLAGS="-O2 -std=gnu89 ${includes}"
        export CXXFLAGS="-O2 -std=gnu++98 ${includes}"
        # The host compiler executable must not bind to this output's older target
        # libstdc++. Link its host C++ runtime statically; target runtimes stay shared.
        export LDFLAGS="-static-libstdc++ -static-libgcc ${links}"
        export AR_FOR_TARGET=${final.binutils}/bin/ar AS_FOR_TARGET=${final.binutils}/bin/as
        export LD_FOR_TARGET=${final.binutils}/bin/ld NM_FOR_TARGET=${final.binutils}/bin/nm
        export RANLIB_FOR_TARGET=${final.binutils}/bin/ranlib
        ${run}
      '';
    };
in
{
  pname = "gcc";
  inherit
    base
    src
    version
    glibc
    binutils
    gmp
    mpfr
    mpc
    zlib
    texinfo
    perl
    file
    which
    ;
  inherit (tools) bash coreutils;
  configurePrefix = "/tvp/gcc-4.9.4";
  patches = [
    ./patches/base-old-no-system-dirs.patch
    ./patches/base-4.9.4-parallel-generators.patch
    ./patches/base-4.9.4-source-date-epoch.patch
    ./patches/base-4.9.4-reload-counter.patch
  ];
  capabilities = {
    languages = [
      "c"
      "c++"
    ];
    libgcc = true;
    libstdcxx = true;
    openmp = true;
    quadmath = true;
    lto = true;
    plugins = true;
    graphite = false;
    sanitizers = false;
    bootstrapComparison = false;
    exclusions = {
      graphite = "This historical C/C++ profile does not select period ISL/CLooG providers.";
      sanitizers = "The historical sanitizer runtime is not ported to the selected modern source libc/kernel headers.";
      bootstrapComparison = "This profile is built once by the explicit earlier source compiler; no self-bootstrap proof is claimed.";
    };
  };
  runtime.loader = "${libc}/lib/ld-linux-x86-64.so.2";
  runtime.libraries = [
    libc
    final.gmp
    final.mpfr
    final.mpc
    final.zlib
  ];
  environment = {
    libraries = [ ];
    tools = [
      tools.coreutils
      final.binutils
      tools.gnumake
      final.texinfo
      final.perl
      final.file
      final.which
      tools.gnutar
      tools.xz
      tools.bzip2
      tools.gzip
      tools.patch
      tools.findutils
      tools.sed
      tools.grep
      tools.gawk
      tools.diffutils
      tools.python
    ];
  };
  configureFlags = [
    "--build=${final.base.platform.config}"
    "--host=${final.base.platform.config}"
    "--target=${final.base.platform.config}"
    "--disable-bootstrap"
    "--enable-languages=c,c++"
    "--disable-multilib"
    "--enable-shared"
    "--enable-checking=release"
    "--enable-lto"
    "--enable-plugin"
    "--enable-threads=posix"
    "--disable-nls"
    "--disable-libssp"
    "--disable-libsanitizer"
    "--without-isl"
    "--without-cloog"
    "--with-system-zlib"
    "--with-gmp=${lib.getDev final.gmp}"
    "--with-mpfr=${lib.getDev final.mpfr}"
    "--with-mpc=${lib.getDev final.mpc}"
    "--with-gnu-as"
    "--with-gnu-ld"
    "--with-as=${final.binutils}/bin/as"
    "--with-ld=${final.binutils}/bin/ld"
    "--with-sysroot=${libc}"
    "--with-native-system-header-dir=/include"
    "--disable-werror"
  ];
  passthru = package: {
    inherit (final) capabilities;
    libc = final.glibc;
    bintools = final.binutils;
    rawCompiler = true;
    defaultHardeningFlags = [ ];
    runtimeDirectories = [
      "${package}/lib"
      "${package}/lib/gcc/${final.base.platform.config}/${final.version}"
      "${final.glibc}/lib"
    ];
    platform = final.base.platform;
  };
  tvp = {
    compilerInterface = "raw-base";
    sourceOwned = true;
    capabilities = final.capabilities;
  };
  meta = {
    description = "GNU C/C++ compiler built with explicit source-owned providers";
    homepage = "https://gcc.gnu.org/";
    license = lib.licenses.gpl3Plus;
    platforms = [ "x86_64-linux" ];
  };
  plan = [
    (steps.unpack {
      src = final.src;
      tar = tools.gnutar;
      bzip2 = tools.bzip2;
      findutils = tools.findutils;
      compression = "bzip2";
    })
    (
      (final.base.environment final.environment)
      // {
        name = "gcc.prepare";
        cwd = "source";
        run = ''
          for patch in ${lib.escapeShellArgs (map (p: "${p}") final.patches)}; do
            ${tools.patch}/bin/patch -p1 < "$patch"
          done
          ${tools.python}/bin/python3 -B ${./native/prepare-base.py} "$PWD" ${shell} ${final.perl}/bin/perl ${final.runtime.loader}
          mkdir "$TVP_SOURCE_ROOT/build"
        '';
      }
    )
    (command "configure" ''
      ${shell} ../source/configure --prefix=${lib.escapeShellArg final.configurePrefix} --libdir=${lib.escapeShellArg "${final.configurePrefix}/lib"} ${lib.escapeShellArgs final.configureFlags}
    '')
    (command "build" ''
      ${tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${shell} \
        "CFLAGS_FOR_TARGET=-O2 ${includes}" \
        "CXXFLAGS_FOR_TARGET=-O2 ${includes}" \
        "LDFLAGS_FOR_TARGET=${links}" all
    '')
    (command "install" ''
      ${tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${shell} \
        "CFLAGS_FOR_TARGET=-O2 ${includes}" \
        "CXXFLAGS_FOR_TARGET=-O2 ${includes}" \
        "LDFLAGS_FOR_TARGET=${links}" DESTDIR="$PWD/install-root" install
      cp -a "install-root${final.configurePrefix}/." "$out/"
      if test -d "$out/lib64" && ! test -L "$out/lib64"; then
        cp -a "$out/lib64/." "$out/lib/"; rm -rf "$out/lib64"; ln -s lib "$out/lib64"
      fi
      ln -sf gcc "$out/bin/cc"; ln -sf g++ "$out/bin/c++"
      mkdir -p "$out/nix-support/production"
      "$out/bin/gcc" -dumpspecs > "$out/nix-support/production/builtin.specs"
      test -s "$out/nix-support/production/builtin.specs"
      for file in "$out/bin/gcc" "$out/bin/g++" \
        "$out/libexec/gcc/${final.base.platform.config}/${final.version}/cc1" \
        "$out/libexec/gcc/${final.base.platform.config}/${final.version}/cc1plus"; do test -x "$file"; done
    '')
    (steps.split "gcc.finalize")
    {
      name = "gcc.copy-public";
      tools = [ tools.coreutils ];
      run = ''
        mkdir -p "$out"
        for directory in bin include lib lib64 libexec share; do
          if test -e "$TVP_ARTIFACT_ROOT/$directory" || test -L "$TVP_ARTIFACT_ROOT/$directory"; then
            ${tools.coreutils}/bin/cp -a --no-preserve=ownership,links "$TVP_ARTIFACT_ROOT/$directory" "$out/"
          fi
        done
        ${tools.coreutils}/bin/chmod -R u+w "$out"
      '';
    }
    {
      name = "gcc.relocate-public";
      tools = [
        tools.python
        final.binutils
        tools.patchelf
      ];
      run = ''${tools.python}/bin/python3 -B ${./native/finalize-standard.py} "$out" "$TVP_ARTIFACT_ROOT" ${lib.escapeShellArg final.configurePrefix} ${final.binutils}/bin/readelf ${tools.patchelf}/bin/patchelf ${../../libraries/libxml2/ordinary/elf.py}'';
    }
    (outputs.interpreters {
      inherit (tools) python patchelf;
      binutils = final.binutils;
      paths = [
        "bin"
        "libexec"
      ];
      loader = final.runtime.loader;
    })
    (outputs.checkPaths {
      inherit (tools) python patchelf;
      binutils = final.binutils;
      elfKinds = [ "runtime" ];
      paths = [
        "bin"
        "libexec"
        "lib"
      ];
    })
  ];
}

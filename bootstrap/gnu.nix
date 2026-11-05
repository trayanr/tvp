# Private ABI transition: M=musl, G=GNU. Nix system equality is not ABI proof.
{ scope }:
let
  inherit (scope) bash;
  source = import ./recipes/gnu/gcc-source.nix {
    inherit (scope)
      lib
      bash
      fetchurl
      gnupatch
      xz
      gnused
      ;
    gnutar = scope.gnutar-latest;
  };
  emptySysroot = bash.runCommand "tvp-bootstrap-gnu-empty-sysroot" { } ''
    mkdir -p "$out/include" "$out/lib"
  '';
in
rec {
  gnu-gcc = import ./recipes/gnu/wrapper.nix {
    inherit scope;
    compiler = gnu-gcc-unwrapped;
    shell = gnu-bash;
    binutils = gnu-binutils;
    libc = gnu-libc;
    runtime = gnu-libgcc;
    cxxRuntime = gnu-libstdcxx;
  };
  gnu-gcc-unwrapped = import ./recipes/gnu/native-compiler.nix {
    inherit scope;
    source = import ./recipes/gnu/gcc-native-source.nix {
      inherit (scope)
        lib
        bash
        fetchurl
        gnupatch
        xz
        gnused
        ;
      gnutar = scope.gnutar-latest;
      gnuLibc = gnu-libc;
    };
    name = "tvp-bootstrap-gcc-16.2.0-M-G-G";
    buildCC = scope.gcc-latest;
    hostCC = gnu-host-driver;
    hostTuple = "x86_64-unknown-linux-gnu";
    targetTuple = "x86_64-unknown-linux-gnu";
    sysroot = gnu-libc;
    hostGmp = gnu-gmp;
    hostMpfr = gnu-mpfr;
    hostMpc = gnu-mpc;
    hostBacktrace = gnu-libbacktrace;
    hostLibiberty = gnu-libiberty;
    buildLibiberty = scope.gcc16-libiberty;
    targetBinutils = gnu-binutils;
    runtime = gnu-libgcc;
    cxxRuntime = gnu-libstdcxx;
  };
  gnu-host-driver = import ./recipes/gnu/cross-wrapper.nix {
    inherit scope;
    cross = gnu-cross;
    libc = gnu-libc;
    runtime = gnu-libgcc;
    cxxRuntime = gnu-libstdcxx;
  };
  inherit
    (import ./recipes/gnu/native-tools.nix {
      inherit scope;
      cc = gnu-runtime-driver;
    })
    gnu-bash
    gnu-binutils
    ;
  gnu-gmp = scope.callPackage ./recipes/gnu/gmp.nix {
    gcc = gnu-host-driver;
    gcc-buildbuild = scope.gcc-latest;
    coreutils = scope.coreutils-musl;
    gnumake = scope.gnumake-musl;
    gnutar = scope.gnutar-latest;
    hostPlatform = {
      config = "x86_64-unknown-linux-gnu";
      isMusl = false;
    };
  };
  gnu-mpfr = scope.callPackage ./recipes/gnu/mpfr.nix {
    gcc = gnu-host-driver;
    gcc-buildbuild = scope.gcc-latest;
    coreutils = scope.coreutils-musl;
    gnumake = scope.gnumake-musl;
    gnutar = scope.gnutar-latest;
    hostPlatform = {
      config = "x86_64-unknown-linux-gnu";
      isMusl = false;
    };
    libgmp = gnu-gmp;
  };
  gnu-mpc = scope.callPackage ./recipes/gnu/mpc.nix {
    gcc = gnu-host-driver;
    gcc-buildbuild = scope.gcc-latest;
    coreutils = scope.coreutils-musl;
    gnumake = scope.gnumake-musl;
    gnutar = scope.gnutar-latest;
    hostPlatform = {
      config = "x86_64-unknown-linux-gnu";
      isMusl = false;
    };
    libgmp = gnu-gmp;
    libmpfr = gnu-mpfr;
  };
  gnu-libiberty = scope.callPackage ./recipes/gnu/libiberty.nix {
    gcc = gnu-host-driver;
    gcc-buildbuild = scope.gcc-latest;
    coreutils = scope.coreutils-musl;
    gnumake = scope.gnumake-musl;
    gnutar = scope.gnutar-latest;
    hostPlatform = {
      config = "x86_64-unknown-linux-gnu";
      isMusl = false;
    };
  };
  gnu-libbacktrace = scope.callPackage ./recipes/gnu/libbacktrace.nix {
    gcc = gnu-host-driver;
    gcc-buildbuild = scope.gcc-latest;
    coreutils = scope.coreutils-musl;
    gnumake = scope.gnumake-musl;
    gnutar = scope.gnutar-latest;
    hostPlatform = {
      config = "x86_64-unknown-linux-gnu";
      isMusl = false;
    };
  };
  gnu-libc-driver = import ./recipes/gnu/cross-wrapper.nix {
    inherit scope;
    cross = gnu-cross;
    libc = gnu-libc;
    runtime = gnu-core-bridge;
  };
  gnu-libgcc = scope.callPackage ./recipes/gnu/libgcc.nix {
    gcc = gnu-libc-driver;
    coreutils = scope.coreutils-musl;
    gnumake = scope.gnumake-musl;
    gnutar = scope.gnutar-latest;
    gcc-buildbuild = scope.gcc-latest;
    binutils-buildbuild = scope.binutils;
    enableShared = true;
    libc = gnu-libc;
    libc-headers = gnu-libc;
    hostPlatform = {
      config = "x86_64-unknown-linux-gnu";
      isMusl = false;
    };
    libgmp = scope.gcc16-gmp;
    libmpfr = scope.gcc16-mpfr;
    libmpc = scope.gcc16-mpc;
    libiberty = scope.gcc16-libiberty;
  };
  gnu-runtime-driver = import ./recipes/gnu/cross-wrapper.nix {
    inherit scope;
    cross = gnu-cross;
    libc = gnu-libc;
    runtime = gnu-libgcc;
  };
  gnu-libstdcxx = scope.callPackage ./recipes/gnu/libstdcxx.nix {
    gcc = gnu-runtime-driver;
    gcc-buildbuild = scope.gcc-latest;
    coreutils = scope.coreutils-musl;
    gnumake = scope.gnumake-musl;
    gnutar = scope.gnutar-latest;
    libgcc = gnu-libgcc;
    libc = gnu-libc;
    dynamicLinkerGlob = "${gnu-libc}/lib/ld-linux-x86-64.so.2";
    staticLibgcc = false;
    hostPlatform = {
      config = "x86_64-unknown-linux-gnu";
      isMusl = false;
    };
  };
  gnu-core-bridge = bash.runCommand "tvp-bootstrap-libgcc-core-bridge" { } ''
    mkdir -p "$out/lib"
    # Exact arithmetic members observed in the direct glibc link trace. No EH,
    # TLS emulation, libc wrappers or musl-specific runtime are transferred.
    ${scope.binutils}/bin/ar x ${scope.gcc16-libgcc}/lib/gcc/x86_64-unknown-linux-musl/16.2.0/libgcc.a _muldc3.o _mulsc3.o _multc3.o _mulxc3.o _popcountsi2.o addtf3.o divtf3.o eqtf2.o extenddftf2.o fixtfdi.o fixtfsi.o floatditf.o floatsitf.o floatunsitf.o getf2.o letf2.o multf3.o sfp-exceptions.o subtf3.o trunctfdf2.o trunctfsf2.o trunctfxf2.o unordtf2.o
    ${scope.binutils}/bin/ar crD "$out/lib/libgcc.a" _muldc3.o _mulsc3.o _multc3.o _mulxc3.o _popcountsi2.o addtf3.o divtf3.o eqtf2.o extenddftf2.o fixtfdi.o fixtfsi.o floatditf.o floatsitf.o floatunsitf.o getf2.o letf2.o multf3.o sfp-exceptions.o subtf3.o trunctfdf2.o trunctfsf2.o trunctfxf2.o unordtf2.o
    ${scope.binutils}/bin/ranlib "$out/lib/libgcc.a"
    cp ${scope.gcc16-libgcc}/lib/gcc/x86_64-unknown-linux-musl/16.2.0/crt*.o "$out/lib/"
  '';
  gnu-libc = import ./recipes/gnu/glibc.nix {
    inherit scope;
    cross = gnu-cross;
    bridge = gnu-core-bridge;
  };
  gnu-cross = import ./recipes/gnu/compiler.nix {
    inherit scope source;
    name = "tvp-bootstrap-gcc-16.2.0-M-M-G";
    buildCC = scope.gcc-latest;
    hostCC = scope.gcc-latest;
    hostTuple = "x86_64-unknown-linux-musl";
    targetTuple = "x86_64-unknown-linux-gnu";
    sysroot = emptySysroot;
    hostGmp = scope.gcc16-gmp;
    hostMpfr = scope.gcc16-mpfr;
    hostMpc = scope.gcc16-mpc;
    hostBacktrace = scope.gcc16-libbacktrace;
    hostLibiberty = scope.gcc16-libiberty;
    buildLibiberty = scope.gcc16-libiberty;
    targetBinutils = scope.binutils;
  };
}

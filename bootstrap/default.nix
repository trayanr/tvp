# Independent of flake.nix, nixpkgs, the catalogue and existing TVP bases.
{
  system ? "x86_64-linux",
}:
assert system == "x86_64-linux";
let
  adapter = import ./adapter.nix { inherit system; };
  inherit (adapter) lib derivationWithMeta;
  platform = {
    inherit system;
    config = "x86_64-unknown-linux-musl";
    isMusl = true;
    isLittleEndian = true;
    is64bit = true;
    isAarch64 = false;
    isRiscV = false;
    canExecute = other: other.system == system;
  };
  pins = builtins.fromJSON (builtins.readFile ./stage0-sources.json);
  sourceTrees = builtins.mapAttrs (
    _: pin:
    builtins.fetchTarball {
      inherit (pin) url sha256;
    }
  ) pins;
  # Nix's own builtin downloader, not a fetched curl/wget or stdenv builder.
  fetchurl =
    attrs:
    import <nix/fetchurl.nix> (
      builtins.removeAttrs attrs [ "url" ]
      // {
        url =
          builtins.replaceStrings
            [
              "mirror://gnu/"
              "mirror://savannah/"
            ]
            [
              "https://ftpmirror.gnu.org/"
              "https://download.savannah.nongnu.org/releases/"
            ]
            attrs.url;
      }
    );
  scope = rec {
    inherit lib derivationWithMeta fetchurl;
    buildPlatform = platform;
    hostPlatform = platform;
    callPackage =
      file: overrides:
      let
        f = import file;
      in
      f (builtins.intersectAttrs (builtins.functionArgs f) scope // overrides);
    stage0 = rec {
      version = "1.9.1";
      platforms = [ system ];
      stage0Arch = "AMD64";
      m2libcArch = "amd64";
      m2libcOS = "Linux";
      baseAddress = "0x00600000";
      inherit (sourceTrees)
        amd64
        m2planet
        m2mesoplanet
        mesccToolsSrc
        mesccToolsExtraSrc
        ;
      m2libc = sourceTrees.m2libc;
      callStage0 =
        file: overrides:
        let
          f = import file;
        in
        f (builtins.intersectAttrs (builtins.functionArgs f) (scope // stage0) // overrides);
      hex0 = callStage0 ./recipes/stage0-posix/hex0.nix { };
      inherit (hex0) hex0-seed;
      boot = callStage0 ./recipes/stage0-posix/mescc-tools-boot.nix { };
      inherit (boot)
        M1
        M2
        hex2
        blood-elf-0
        kaem-unwrapped
        ;
      mescc-tools = callStage0 ./recipes/stage0-posix/mescc-tools { };
      mescc-tools-extra = callStage0 ./recipes/stage0-posix/mescc-tools-extra { };
      kaem = callStage0 ./recipes/stage0-posix/kaem { };
    };
    inherit (stage0) kaem mescc-tools mescc-tools-extra;
    # Text is data written by Nix; executing a text file still requires the
    # explicitly declared source-built interpreter.
    writeText =
      name: text:
      derivationWithMeta {
        inherit name text;
        copy = "${mescc-tools-extra}/bin/cp";
        passAsFile = [ "text" ];
        builder = "${kaem}/bin/kaem";
        args = [
          "--strict"
          "--file"
          (builtins.toFile "write-text.kaem" ''
            ''${copy} ''${textPath} ''${out}
          '')
        ];
      };
    mes = callPackage ./recipes/mes { };
    ln-boot = callPackage ./recipes/ln-boot { };
    mes-libc = callPackage ./recipes/mes/libc.nix { };
    tinycc-bootstrappable = callPackage ./recipes/tinycc/bootstrappable.nix { };
    tinycc-mes = callPackage ./recipes/tinycc/mes.nix { };
    gnupatch = callPackage ./recipes/gnupatch { tinycc = tinycc-mes; };
    gnumake = callPackage ./recipes/gnumake { tinycc = tinycc-bootstrappable; };
    coreutils = callPackage ./recipes/coreutils { tinycc = tinycc-mes; };
    bash_2_05 = callPackage ./recipes/bash/2.nix { tinycc = tinycc-mes; };
    gnused-mes = callPackage ./recipes/gnused/mes.nix {
      bash = bash_2_05;
      tinycc = tinycc-bootstrappable;
    };
    gnugrep = callPackage ./recipes/gnugrep {
      bash = bash_2_05;
      tinycc = tinycc-mes;
    };
    gnutar = callPackage ./recipes/gnutar/mes.nix {
      bash = bash_2_05;
      tinycc = tinycc-mes;
      gnused = gnused-mes;
    };
    gzip = callPackage ./recipes/gzip {
      bash = bash_2_05;
      tinycc = tinycc-bootstrappable;
      gnused = gnused-mes;
    };
    gawk-mes = callPackage ./recipes/gawk/mes.nix {
      bash = bash_2_05;
      tinycc = tinycc-mes;
      gnused = gnused-mes;
    };
    musl-tcc-intermediate = callPackage ./recipes/musl/tcc.nix {
      bash = bash_2_05;
      tinycc = tinycc-mes;
      gnused = gnused-mes;
    };
    tinycc-musl-intermediate = callPackage ./recipes/tinycc/musl.nix {
      bash = bash_2_05;
      musl = musl-tcc-intermediate;
      tinycc = tinycc-mes;
    };
    musl-tcc = callPackage ./recipes/musl/tcc.nix {
      bash = bash_2_05;
      tinycc = tinycc-musl-intermediate;
      gnused = gnused-mes;
    };
    tinycc-musl = callPackage ./recipes/tinycc/musl.nix {
      bash = bash_2_05;
      musl = musl-tcc;
      tinycc = tinycc-musl-intermediate;
    };
    gnutar-musl = callPackage ./recipes/gnutar/musl.nix {
      bash = bash_2_05;
      tinycc = tinycc-musl;
      gnused = gnused-mes;
    };
    gnumake-musl = callPackage ./recipes/gnumake/musl.nix {
      bash = bash_2_05;
      tinycc = tinycc-musl;
      gawk = gawk-mes;
      gnumakeBoot = gnumake;
      gnutar = gnutar-musl;
    };
    coreutils-musl = callPackage ./recipes/coreutils/musl.nix {
      bash = bash_2_05;
      tinycc = tinycc-musl;
      gnumake = gnumake-musl;
      gnutar = gnutar-musl;
    };
    gnused = callPackage ./recipes/gnused {
      bash = bash_2_05;
      tinycc = tinycc-musl;
      gnused = gnused-mes;
    };
    gawk = callPackage ./recipes/gawk {
      bash = bash_2_05;
      tinycc = tinycc-musl;
      gnumake = gnumake-musl;
      gnutar = gnutar-musl;
      bootGawk = gawk-mes;
    };
    xz = callPackage ./recipes/xz {
      bash = bash_2_05;
      tinycc = tinycc-musl;
      gnumake = gnumake-musl;
      gnutar = gnutar-musl;
    };
    diffutils = callPackage ./recipes/diffutils {
      bash = bash_2_05;
      tinycc = tinycc-musl;
      gnumake = gnumake-musl;
      gnutar = gnutar-musl;
    };
    findutils = callPackage ./recipes/findutils {
      tinycc = tinycc-musl;
      gnumake = gnumake-musl;
      gnutar = gnutar-musl;
    };
    bash = callPackage ./recipes/bash {
      bootBash = bash_2_05;
      tinycc = tinycc-musl;
      coreutils = coreutils-musl;
      gnumake = gnumake-musl;
      gnutar = gnutar-musl;
    };
    binutils = callPackage ./recipes/binutils {
      tinycc = tinycc-musl;
      gnumake = gnumake-musl;
      gnutar = gnutar-musl;
    };
    gcc46 = callPackage ./recipes/gcc/4.6.nix {
      tinycc = tinycc-musl;
      gnumake = gnumake-musl;
      gnutar = gnutar-musl;
    };
    musl = callPackage ./recipes/musl {
      gcc = gcc46;
      gnumake = gnumake-musl;
    };
    gcc46-cxx = callPackage ./recipes/gcc/4.6.cxx.nix {
      gcc = gcc46;
      gnumake = gnumake-musl;
      gnutar = gnutar-musl;
    };
    bzip2 = callPackage ./recipes/bzip2 {
      tinycc = tinycc-musl;
      gnumake = gnumake-musl;
      gnutar = gnutar-musl;
    };
    gnutar-latest = callPackage ./recipes/gnutar/latest.nix {
      gcc = gcc46;
      gnumake = gnumake-musl;
      gnutarBoot = gnutar-musl;
    };
    gcc10-unwrapped = callPackage ./recipes/gcc/10.nix {
      gcc = gcc46-cxx;
      coreutils = coreutils-musl;
      gnumake = gnumake-musl;
      gnutar = gnutar-latest;
    };
    gcc10 = callPackage ./recipes/gcc/wrapper.nix {
      gcc-unwrapped = gcc10-unwrapped;
      bash-build = bash;
      libc = musl;
      libgcc = gcc10-unwrapped;
      libstdcxx = gcc10-unwrapped;
      targetPlatform = platform;
      dynamicLinkerGlob = "${musl}/lib/libc.so";
      staticLibgcc = true;
    };
    gcc16-gmp = callPackage ./recipes/gcc/gmp.nix {
      gcc = gcc10;
      coreutils = coreutils-musl;
      gnumake = gnumake-musl;
      gnutar = gnutar-latest;
      gcc-buildbuild = gcc10;
    };

    gcc16-mpfr = callPackage ./recipes/gcc/mpfr.nix {
      gcc = gcc10;
      coreutils = coreutils-musl;
      gnumake = gnumake-musl;
      gnutar = gnutar-latest;
      libgmp = gcc16-gmp;
    };

    gcc16-mpc = callPackage ./recipes/gcc/mpc.nix {
      gcc = gcc10;
      coreutils = coreutils-musl;
      gnumake = gnumake-musl;
      gnutar = gnutar-latest;
      libgmp = gcc16-gmp;
      libmpfr = gcc16-mpfr;
    };

    gcc16-libbacktrace = callPackage ./recipes/gcc/libbacktrace.nix {
      gcc = gcc10;
      coreutils = coreutils-musl;
      gnumake = gnumake-musl;
      gnutar = gnutar-latest;

    };

    gcc16-libiberty = callPackage ./recipes/gcc/libiberty.nix {
      gcc = gcc10;
      coreutils = coreutils-musl;
      gnumake = gnumake-musl;
      gnutar = gnutar-latest;

    };

    gcc-latest-unwrapped = callPackage ./recipes/gcc/ng.nix {
      gcc = gcc10;
      coreutils = coreutils-musl;
      gnumake = gnumake-musl;
      gnutar = gnutar-latest;
      gcc-buildbuild = gcc10;
      binutils-buildbuild = binutils;
      binutils-buildtarget = binutils;
      binutils-hosttarget = binutils;
      libc = musl;
      libc-headers = musl;
      targetPlatform = platform;
      libgmp = gcc16-gmp;
      libmpfr = gcc16-mpfr;
      libmpc = gcc16-mpc;
      libbacktrace = gcc16-libbacktrace;
      libiberty = gcc16-libiberty;
    };

    gcc16-libgcc = callPackage ./recipes/gcc/libgcc.nix {
      gcc = gcc-latest-unwrapped;
      coreutils = coreutils-musl;
      gnumake = gnumake-musl;
      gnutar = gnutar-latest;
      gcc-buildbuild = gcc10;
      binutils-buildbuild = binutils;
      enableShared = false;
      libc = musl;
      libc-headers = musl;
      libgmp = gcc16-gmp;
      libmpfr = gcc16-mpfr;
      libmpc = gcc16-mpc;
      libiberty = gcc16-libiberty;
    };

    gcc16-libstdcxx = callPackage ./recipes/gcc/libstdcxx.nix {
      gcc = gcc-latest-unwrapped;
      coreutils = coreutils-musl;
      gnumake = gnumake-musl;
      gnutar = gnutar-latest;
      libgcc = gcc16-libgcc;
      libc = musl;
      dynamicLinkerGlob = "${musl}/lib/libc.so";
      staticLibgcc = true;
    };

    inherit (import ./prerequisites.nix { inherit scope; })
      linux-headers
      build-m4
      build-bison
      build-python
      build-grep
      ;

    inherit (import ./gnu.nix { inherit scope; })
      gnu-gcc
      gnu-gcc-unwrapped
      gnu-cross
      gnu-core-bridge
      gnu-libc
      gnu-libgcc
      gnu-libstdcxx
      gnu-bash
      gnu-binutils
      gnu-gmp
      gnu-mpfr
      gnu-mpc
      gnu-libiberty
      gnu-libbacktrace
      ;

    gcc-latest = callPackage ./recipes/gcc/wrapper.nix {
      gcc-unwrapped = gcc-latest-unwrapped;
      bash-build = bash;
      libc = musl;
      libgcc = gcc16-libgcc;
      libstdcxx = gcc16-libstdcxx;
      targetPlatform = platform;
      dynamicLinkerGlob = "${musl}/lib/libc.so";
      staticLibgcc = true;
    };

  };
  tests = import ./tests.nix { inherit scope; };
in
{
  inherit (scope)
    stage0
    mes
    mes-libc
    tinycc-bootstrappable
    tinycc-mes
    gnupatch
    gnumake
    coreutils
    bash_2_05
    gnused-mes
    gnugrep
    gnutar
    gzip
    gawk-mes
    musl-tcc-intermediate
    tinycc-musl-intermediate
    musl-tcc
    tinycc-musl
    gnutar-musl
    gnumake-musl
    coreutils-musl
    gnused
    gawk
    xz
    diffutils
    findutils
    bash
    binutils
    gcc46
    musl
    gcc46-cxx
    bzip2
    gnutar-latest
    gcc10-unwrapped
    gcc10
    gcc16-gmp
    gcc16-mpfr
    gcc16-mpc
    gcc16-libbacktrace
    gcc16-libiberty
    gcc-latest-unwrapped
    gcc16-libgcc
    gcc16-libstdcxx
    gcc-latest
    linux-headers
    build-m4
    build-bison
    build-python
    build-grep
    ;
  inherit (scope)
    gnu-gcc
    gnu-gcc-unwrapped
    gnu-cross
    gnu-core-bridge
    gnu-libc
    gnu-libgcc
    gnu-libstdcxx
    gnu-bash
    gnu-binutils
    gnu-gmp
    gnu-mpfr
    gnu-mpc
    gnu-libiberty
    gnu-libbacktrace
    ;
  gnu-tests = import ./gnu-tests.nix {
    inherit scope;
    gnu = import ./gnu.nix { inherit scope; };
  };
  inherit tests;
  compiler = scope.tinycc-mes.compiler;
  libc = scope.tinycc-mes.libs;
  sources = sourceTrees;
}

# Complete native source-GNU procedure for 2.42 only; retained construction generations remain independent.
{
  tvp,
  lib,
  base,
  src,
  version,
  bash,
  coreutils,
  gnumake,
  gnutar,
  python,
  binutils,
  patchelf,
  sed,
  grep,
  gawk,
  diffutils,
  findutils,
  gzip,
  xz,
  zlib,
  zstd,
  perl,
  pkg-config,
  bison,
  texinfo,
  cStandard ? "gnu17",
  configureFlags ? [ ],
  doCheck ? true,
  gprofng ? true,
}:
final:
let
  inherit (tvp.builder) steps outputs;
  command =
    name: run:
    (final.base.environment final.environment)
    // {
      name = "binutils.${name}";
      cwd = "source";
      inherit run;
    };
  make = ''${final.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${final.bash}/bin/bash'';
in
{
  pname = "binutils";
  inherit
    base
    src
    version
    bash
    coreutils
    gnumake
    gnutar
    python
    binutils
    patchelf
    sed
    grep
    gawk
    diffutils
    findutils
    gzip
    xz
    zlib
    zstd
    perl
    pkg-config
    bison
    texinfo
    cStandard
    configureFlags
    doCheck
    gprofng
    ;
  environment = {
    tools = [
      final.gnumake
      final.sed
      final.grep
      final.gawk
      final.diffutils
      final.findutils
      final.perl
      final.pkg-config
      final.bison
      final.texinfo
    ];
    libraries = [
      final.zlib
      final.zstd
    ];
  };
  runtime = {
    libraries = final.environment.libraries;
    dlopenDirectories = [ ];
  };
  development.libraries = [
    final.zlib
    final.zstd
  ];
  plan = steps.sequence [
    (steps.unpack {
      src = final.src;
      tar = final.gnutar;
      findutils = final.findutils;
      xz = final.xz;
    })
    (steps.shebangs {
      name = "binutils.source-shells";
      python = final.python;
      paths = [
        "configure"
        "bfd"
        "binutils"
        "gas"
        "gprof"
        "gprofng"
        "ld"
        "libctf"
        "libsframe"
        "libiberty"
        "config"
      ];
      names = [
        "sh"
        "bash"
      ];
      interpreter = "${final.bash}/bin/bash";
    })
    (command "prepare" ''
      ${final.python}/bin/python3 -B ${./prepare.py} "$PWD" ${../../../../lib/native-output}
    '')
    (command "configure" ''
      export CONFIG_SHELL=${final.bash}/bin/bash
      # The base wrapper retains include, optimization and hardening flags.
      # This upstream compatibility dialect applies to C, never C++.
      export CFLAGS="''${CFLAGS:--g -O2} -std=${final.cStandard}"
      mkdir ../build
      cd ../build
      ${final.bash}/bin/bash ../source/configure --prefix="$out" --with-system-zlib --with-zstd \
        --enable-plugins --enable-deterministic-archives --with-lib-path=: \
        ${
          lib.optionalString (!final.gprofng) "--disable-gprofng"
        } ${lib.escapeShellArgs final.configureFlags}
    '')
    ((command "build" make) // { cwd = "build"; })
    # Affordable shipped checks; DejaGNU's target matrix is outside this gate.
    (
      (
        (command "check" "${make} check-libiberty check-libsframe")
        // {
          cwd = "build";
          enabled = final.doCheck;
        }
      )
    )
    (
      (command "install" ''
        ${make} install
        # Install the support archive beside BFD/CTF, independent of GCC's multilib layout.
        ${make} -C libiberty install target_header_dir=libiberty MULTIOSDIR=.
      '')
      // {
        cwd = "build";
      }
    )
    (outputs.shebangs {
      python = final.python;
      paths = [ "bin" ];
      names = [ "perl" ];
      interpreter = "${final.perl}/bin/perl";
    })
    (outputs.strip {
      python = final.python;
      binutils = final.binutils;
      paths = [
        "bin"
        "lib"
      ];
    })
    (outputs.stripArchives {
      python = final.python;
      binutils = final.binutils;
      paths = [ "lib" ];
    })
    (outputs.rpaths {
      python = final.python;
      binutils = final.binutils;
      patchelf = final.patchelf;
      base = final.base;
      libraries = final.runtime.libraries;
      dlopenDirectories = final.runtime.dlopenDirectories or [ ];
      paths = [
        "bin"
        "lib"
      ];
    })
    {
      name = "output.self-rpaths";
      tools = [
        final.python
        final.patchelf
      ];
      run = ''
        ${final.python}/bin/python3 -B ${./self-rpaths.py} "$out" ${../../../../lib/native-output} ${final.binutils}/bin/readelf ${final.patchelf}/bin/patchelf
      '';
    }
    (outputs.development {
      python = final.python;
      libraries = final.development.libraries or [ ];
    })
    (outputs.checkPaths {
      python = final.python;
      binutils = final.binutils;
      patchelf = final.patchelf;
      paths = [
        "bin"
        "lib"
      ];
    })
  ];
  tvp.features = {
    gprofng = final.gprofng;
    plugins = true;
    deterministicArchives = true;
    libiberty = true;
  };
  meta = {
    description = "GNU assembler, linker and binary inspection tools (unwrapped)";
    license = lib.licenses.gpl3Plus;
    platforms = [ "x86_64-linux" ];
    priority = 10;
  };
}

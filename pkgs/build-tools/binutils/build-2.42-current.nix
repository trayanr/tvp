# Complete native source-GNU procedure for 2.42 only; retained construction generations remain independent.
{
  tvp,
  lib,
  base,
  src,
  version,
  binutils,
  zlib,
  zstd,
  perl,
  bison,
  texinfo,
  cStandard ? "gnu17",
  configureFlags ? [ ],
  doCheck ? true,
  gprofng ? true,
}:
final:
let
  context = tvp.builder.forBase final.base;
  inherit (context) steps outputs;
  baseTools = context.tools;
  bash = baseTools.bash;
  coreutils = baseTools.coreutils;
  diffutils = baseTools.diffutils;
  findutils = baseTools.findutils;
  gawk = baseTools.gawk;
  gnumake = baseTools.gnumake;
  gnutar = baseTools.gnutar;
  grep = baseTools.grep;
  gzip = baseTools.gzip;
  patchelf = baseTools.patchelf;
  pkg-config = baseTools.pkg-config;
  python = baseTools.python;
  sed = baseTools.sed;
  xz = baseTools.xz;
in

let
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
  bash = baseTools.bash;
  coreutils = baseTools.coreutils;
  diffutils = baseTools.diffutils;
  findutils = baseTools.findutils;
  gawk = baseTools.gawk;
  gnumake = baseTools.gnumake;
  gnutar = baseTools.gnutar;
  grep = baseTools.grep;
  gzip = baseTools.gzip;
  patchelf = baseTools.patchelf;
  pkg-config = baseTools.pkg-config;
  python = baseTools.python;
  sed = baseTools.sed;
  xz = baseTools.xz;
  # Equal-width compiled-prefix ABI; the artifact remains a distinct producer.
  artifactName = "${final.pname}-${final.version}";
  inherit
    base
    src
    version
    binutils
    zlib
    zstd
    perl
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
  # Affordable shipped checks; the DejaGNU target matrix remains outside this gate.
  upstreamCheck = (command "check" "${make} check-libiberty check-libsframe") // {
    enabled = final.doCheck;
  };

  originalPlan = steps.sequence [
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
      ${final.python}/bin/python3 -B ${./native/prepare.py} "$PWD" ${../../../lib/native-output}
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
    (steps.split "binutils.finalize")
    (outputs.copyArtifacts { coreutils = final.coreutils; })
    {
      name = "binutils.relocate";
      tools = [ final.python ];
      run = ''${final.python}/bin/python3 -B ${../owned-split-output.py} "$out" "$TVP_ARTIFACT_ROOT" ${
        lib.escapeShellArg (
          builtins.toJSON {
            text = [ ];
            slots = [ ];
            fixed = [ ];
          }
        )
      } ${../../../lib/installed-tree.py}'';
    }
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
        ${final.python}/bin/python3 -B ${./native/self-rpaths.py} "$out" ${../../../lib/native-output} ${final.binutils}/bin/readelf ${final.patchelf}/bin/patchelf
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

  upstreamPlan = artifact: [
    {
      name = "binutils.restore-build-tree";
      tools = [ baseTools.python ];
      run = ''
        ${baseTools.python}/bin/python3 -B ${../../../lib/utilities-checkpoint.py} restore ${artifact}/nix-support/binutils-build-tree "$TVP_SOURCE_ROOT"
      '';
    }
  ];
  plan =
    let
      parts = steps.partition final.originalPlan;
    in
    parts.first
    ++ [
      {
        name = "binutils.save-build-tree";
        tools = [
          baseTools.python
          final.coreutils
        ];
        run = ''
          sourcePath=$(${final.coreutils}/bin/realpath "$TVP_SOURCE_ROOT/source")
          buildPath=$(${final.coreutils}/bin/realpath "$TVP_SOURCE_ROOT/build")
          ${baseTools.python}/bin/python3 -B ${../../../lib/utilities-checkpoint.py} save "$TVP_SOURCE_ROOT" "$out/nix-support/binutils-build-tree" "[\"$sourcePath\",\"$buildPath\"]" "$buildPath"
        '';
      }
    ]
    ++ (lib.optional parts.split (steps.split "binutils.finalize"))
    ++ [
      (builtins.head parts.second)
      {
        name = "binutils.drop-build-tree";
        tools = [ final.coreutils ];
        run = ''${final.coreutils}/bin/rm -rf -- "$out/nix-support/binutils-build-tree"'';
      }
    ]
    ++ builtins.tail parts.second;
}

# 1.1.2 only: configure parses one option, takes the prefix from its environment and probes FHS headers.
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
  gzip,
  python,
  binutils,
  patchelf,
  sed,
  grep,
  gawk,
  diffutils,
  findutils,
  doCheck ? true,
  cStandard ? "gnu89",
  cFlags ? [ ],
  reportedVersion ? version,
  libraryVersion ? version,
  configureFlags ? [ "--shared" ],
  patches ? [ ],
  preparation ? {
    selections = [
      "configure"
      "Makefile.in"
      "zlib.h"
      "zutil.h"
    ];
    edits = [ ];
  },
  features ? {
    libName = "z";
    versionFunction = true;
    compress2 = true;
    pkgConfig = false;
    static = false;
  },
}:
let
  inherit (tvp.builder) steps outputs;

in
final:
let
  elfPaths = [ "lib/libz.so.${final.libraryVersion}" ];
  environment = final.base.environment final.environment;
  command =
    name: run:
    environment
    // {
      inherit name run;
      cwd = "source";
    };
  make = ''${final.tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${final.bash}/bin/bash'';
  rpaths =
    {
      python,
      binutils,
      patchelf,
      base,
      paths,
      libraries,
      dlopenDirectories ? [ ],
    }:
    {
      name = "output.rpaths";
      tools = [
        python
        binutils
        patchelf
      ];
      run = ''${python}/bin/python3 -B ${./rpaths.py} "$out" ${
        lib.escapeShellArg (
          builtins.toJSON {
            inherit paths dlopenDirectories;
            elfKinds = null;
            libraries = lib.concatMap (
              p: (p.development or { }).libraryDirectories or [ "${lib.getLib p}/lib" ]
            ) libraries;
            baseDirectories = base.runtimeDirectories;
            readelf = "${binutils}/bin/readelf";
            patchelf = "${patchelf}/bin/patchelf";
          }
        )
      } ${../../../../lib/native-output}'';
    };

in
{
  pname = "zlib";
  inherit
    base
    src
    version
    bash
    coreutils
    ;
  tools = {
    inherit
      gnumake
      gnutar
      gzip
      findutils
      python
      binutils
      patchelf
      sed
      grep
      gawk
      diffutils
      ;
  };
  libraries = { };
  inherit
    doCheck
    cStandard
    cFlags
    reportedVersion
    libraryVersion
    configureFlags
    patches
    preparation
    features
    ;
  stripFlags = [
    "-S"
    "-p"
  ];
  dependencyProviders = final.tools // final.libraries;
  environment = {
    tools = [
      final.tools.gnumake
      final.tools.sed
      final.tools.grep
      final.tools.gawk
      final.tools.diffutils
      final.tools.findutils
    ];
    libraries = [ ];
  };
  runtime = {
    libraries = [ ];
    shell = final.bash;
    pager = final.coreutils;
    tools = [
      final.coreutils
      final.tools.sed
      final.tools.grep
      final.tools.diffutils
    ];
  };
  plan = steps.sequence [
    (steps.unpack {
      src = final.src;
      gzip = final.tools.gzip;
      findutils = final.tools.findutils;
      tar = final.tools.gnutar;
      compression = "gzip";
    })
    {
      name = "zlib.prepare";
      cwd = "source";
      tools = [ final.tools.python ];
      env = environment.env;
      run = ''${final.tools.python}/bin/python3 -B ${./source.py} ${final.bash}/bin/bash ${
        lib.escapeShellArg (
          builtins.toJSON (
            final.preparation
            // {
              patches = map (p: {
                path = "${p}";
                sha256 = builtins.hashFile "sha256" p;
              }) final.patches;
            }
          )
        )
      }'';
    }
    (command "zlib.configure" ''
      sed -i -e 's|test ! -f /usr/include/errno.h|false|' -e 's|test -f /usr/include/unistd.h|true|' configure
      export AR="${final.tools.binutils}/bin/ar rc"
      export CFLAGS="''${CFLAGS--O3} -std=${final.cStandard} -fPIC ${lib.escapeShellArgs final.cFlags}"
      export LDSHARED="$CC -shared -Wl,-soname,libz.so.1"
      prefix="$out" ./configure ${lib.escapeShellArgs final.configureFlags}
    '')
    (command "zlib.build" make)
    (command "zlib.install" ''
      mkdir -p "$out/include" "$out/lib"
      ${make} install
      mkdir -p "$out/nix-support"
      cp "$TVP_SOURCE_ROOT/source-date-epoch" "$out/nix-support/source-date-epoch"
    '')
    (steps.split "zlib.finalize")
    (outputs.copyArtifacts { coreutils = final.coreutils; })
    {
      name = "zlib.relocate-runtime";
      tools = [
        final.tools.python
        final.tools.patchelf
        final.tools.binutils
      ];
      run = ''${final.tools.python}/bin/python3 -B ${./output.py} "$out" "$TVP_ARTIFACT_ROOT" ${final.tools.patchelf}/bin/patchelf ${
        lib.escapeShellArg (
          builtins.toJSON {
            requiredRegular = [
              "include/zlib.h"
              "include/zconf.h"
            ];
            requiredFiles = [
              "include/zlib.h"
              "include/zconf.h"
              "lib/libz.so.${final.libraryVersion}"
            ];
            requiredDirectories = [
              "lib"
              "include"
            ];
            readelf = "${final.tools.binutils}/bin/readelf";
            buildShell = "${final.bash}/bin/bash";
            shell = "${final.runtime.shell}/bin/bash";
            pager = "${final.runtime.pager}/bin/cat";
            paths = map (p: "${p}/bin") final.runtime.tools;
          }
        )
      }'';
    }
    (outputs.strip {
      flags = final.stripFlags;
      python = final.tools.python;
      binutils = final.tools.binutils;
      paths = elfPaths;
    })
    (rpaths {
      python = final.tools.python;
      binutils = final.tools.binutils;
      patchelf = final.tools.patchelf;
      base = final.base;
      paths = elfPaths;
      libraries = final.runtime.libraries;
      dlopenDirectories = final.runtime.dlopenDirectories or [ ];
    })
    (outputs.development {
      python = final.tools.python;
      libraries = [ ];
    })
    {
      name = "output.manuals";
      tools = [
        final.tools.gzip
        final.tools.findutils
      ];
      run = ''if test -f "$out/share/man/man3/zlib.3"; then ${final.tools.gzip}/bin/gzip -n -9 "$out/share/man/man3/zlib.3"; fi'';
    }
    (outputs.checkSymlinks {
      python = final.tools.python;
      paths = [
        "lib/libz.so"
        "lib/libz.so.1"
      ];
    })
    ((import ./check-paths.nix { inherit lib; }) {
      python = final.tools.python;
      binutils = final.tools.binutils;
      patchelf = final.tools.patchelf;
      paths = elfPaths;
    })
  ];
  tvp = {
    reportedVersion = final.reportedVersion;
    features = final.features;
  };
  meta = {
    name = "zlib-${final.version}";
    outputsToInstall = [ "out" ];
    available = true;
    broken = false;
    insecure = false;
    unfree = false;
    unsupported = false;
    description = "Lossless data-compression library implementing the DEFLATE algorithm";
    homepage = "https://zlib.net/";
    license = lib.licenses.zlib;
    platforms = lib.platforms.unix;
  };
}

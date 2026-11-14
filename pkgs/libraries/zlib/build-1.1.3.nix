# 1.1.3–1.2.2.4, except 1.2.0/1.2.0.1 and 1.2.0.5–1.2.0.7: multi-option configure and compiler-based header probes. Independent upstream checkpoint.
{
  tvp,
  lib,
  base,
  src,
  version,
  doCheck ? true,
  cStandard ? "gnu89",
  cFlags ? [ ],
  configureFlags ? [ "--shared" ],
  patches ? [ ],
  linkExamplesAgainstShared ? false,
  createManDir ? false,
}:
final:
let
  context = tvp.builder.forBase final.base;
  inherit (context) steps outputs tools;
  environment = final.base.environment final.environment;
  command =
    name: run:
    environment
    // {
      inherit name run;
      cwd = "source";
    };
  make = ''${tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${tools.bash}/bin/bash'';
  elfPaths = [ "lib/libz.so.${final.installedInterface.libraryVersion}" ];
  checkpoint = "nix-support/zlib-build-tree";
  rpaths = {
    name = "output.rpaths";
    tools = [
      tools.python
      tools.binutils
      tools.patchelf
    ];
    run = ''${tools.python}/bin/python3 -B ${./rpaths.py} "$out" ${
      lib.escapeShellArg (
        builtins.toJSON {
          paths = elfPaths;
          dlopenDirectories = final.runtime.dlopenDirectories or [ ];
          elfKinds = null;
          libraries = lib.concatMap (
            p: (p.development or { }).libraryDirectories or [ "${lib.getLib p}/lib" ]
          ) final.runtime.libraries;
          baseDirectories = final.base.runtimeDirectories;
          readelf = "${tools.binutils}/bin/readelf";
          patchelf = "${tools.patchelf}/bin/patchelf";
        }
      )
    } ${../../../lib/native-output}'';
  };
in
{
  pname = "zlib";
  inherit
    base
    src
    version
    doCheck
    cStandard
    cFlags
    configureFlags
    patches
    ;
  inherit linkExamplesAgainstShared createManDir;
  inherit (tools) bash coreutils;
  buildFeatures = {
    cStandard = final.cStandard;
    linkExamplesAgainstShared = final.linkExamplesAgainstShared;
  };
  sourceLayout = {
    selections = [
      "configure"
      "Makefile.in"
      "zlib.h"
      "zutil.h"
    ];
    edits = [ ];
  };
  installedInterface = {
    libraryVersion = final.version;
    reportedVersion = final.version;
    libName = "z";
    versionFunction = true;
    compress2 = true;
    pkgConfig = false;
    static = false;
  };
  stripFlags = [
    "-S"
    "-p"
  ];
  environment = {
    tools = [
      tools.gnumake
      tools.sed
      tools.grep
      tools.gawk
      tools.diffutils
      tools.findutils
    ];
    libraries = [ ];
  };
  runtime = {
    libraries = [ ];
    dlopenDirectories = [ ];
    shell = tools.bash;
    pager = tools.coreutils;
    tools = [
      tools.coreutils
      tools.sed
      tools.grep
      tools.diffutils
    ];
  };
  productionPlan = steps.sequence [
    (steps.unpack {
      src = final.src;
      compression = "gzip";
    })
    {
      name = "zlib.prepare";
      cwd = "source";
      tools = [ tools.python ];
      env = environment.env;
      run = ''${tools.python}/bin/python3 -B ${./source.py} ${tools.bash}/bin/bash ${
        lib.escapeShellArg (
          builtins.toJSON (
            final.sourceLayout
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
      export AR="${tools.binutils}/bin/ar rc"
      export CFLAGS="''${CFLAGS--O3} -std=${final.cStandard} -fPIC ${lib.escapeShellArgs final.cFlags}"
      export LDSHARED="$CC -shared -Wl,-soname,libz.so.1"
      ./configure --prefix="$out" ${lib.escapeShellArgs final.configureFlags}
    '')
    (command "zlib.build" ''${make} libz.so.${final.installedInterface.libraryVersion}'')
    (command "zlib.install" ''
      mkdir -p "$out/include" "$out/lib"
      ${lib.optionalString final.createManDir ''mkdir -p "$out/share/man/man3"''}
      ${make} install
      mkdir -p "$out/nix-support"
      cp "$TVP_SOURCE_ROOT/source-date-epoch" "$out/nix-support/source-date-epoch"
    '')
    (
      (command "zlib.save-build-tree" ''
        ${tools.python}/bin/python3 -B ${../../../lib/build-checkpoint.py} "$TVP_SOURCE_ROOT" "$out/${checkpoint}"
      '')
      // {
        tools = environment.tools ++ [ tools.python ];
      }
    )
  ];
  upstreamPlan = artifact: [
    {
      name = "zlib.restore-build-tree";
      tools = [ tools.python ];
      run = ''${tools.python}/bin/python3 -B ${./tests/restore.py} ${artifact}/${checkpoint} "$TVP_SOURCE_ROOT"'';
    }
  ];
  upstreamCheck =
    (command "zlib.check" ''
      export LD_LIBRARY_PATH="$PWD:''${LD_LIBRARY_PATH-}"
      status=0
      # Upstream example variants share foo.gz. Compile in parallel, test in order.
      ${lib.optionalString final.linkExamplesAgainstShared "sed -i 's|^LDFLAGS=libz.a|LDFLAGS=$(LIBS)|' Makefile"}
      ${make} all
      ${tools.gnumake}/bin/make -j1 SHELL=${tools.bash}/bin/bash test > upstream-check.log 2>&1 || status=$?
      cat upstream-check.log >&2
      if test "$status" -ne 0; then exit "$status"; fi
      if ${tools.grep}/bin/grep -E 'FAILED|FAIL|XPASS' upstream-check.log >&2; then exit 1; fi
    '')
    // {
      enabled = final.doCheck;
    };
  plan = final.productionPlan ++ [
    (steps.split "zlib.finalize")
    (outputs.copyArtifacts { })
    {
      name = "zlib.drop-build-tree";
      tools = [ tools.coreutils ];
      run = ''${tools.coreutils}/bin/rm -rf -- "$out/${checkpoint}"'';
    }
    {
      name = "zlib.relocate-runtime";
      tools = [
        tools.python
        tools.patchelf
        tools.binutils
      ];
      run = ''${tools.python}/bin/python3 -B ${./output.py} "$out" "$TVP_ARTIFACT_ROOT" ${tools.patchelf}/bin/patchelf ${
        lib.escapeShellArg (
          builtins.toJSON {
            requiredRegular = [
              "include/zlib.h"
              "include/zconf.h"
            ];
            requiredFiles = [
              "include/zlib.h"
              "include/zconf.h"
              "lib/libz.so.${final.installedInterface.libraryVersion}"
            ];
            requiredDirectories = [
              "lib"
              "include"
            ];
            readelf = "${tools.binutils}/bin/readelf";
            buildShell = "${tools.bash}/bin/bash";
            shell = "${final.runtime.shell}/bin/bash";
            pager = "${final.runtime.pager}/bin/cat";
            paths = map (p: "${p}/bin") final.runtime.tools;
          }
        )
      }'';
    }
    (outputs.strip {
      paths = elfPaths;
      flags = final.stripFlags;
    })
    rpaths
    (outputs.development { libraries = [ ]; })
    {
      name = "output.manuals";
      tools = [ tools.gzip ];
      run = ''if test -f "$out/share/man/man3/zlib.3"; then ${tools.gzip}/bin/gzip -n -9 "$out/share/man/man3/zlib.3"; fi'';
    }
    (outputs.checkSymlinks {
      paths = [
        "lib/libz.so"
        "lib/libz.so.1"
      ];
    })
    ((import ./check-paths.nix { inherit lib; }) {
      python = tools.python;
      binutils = tools.binutils;
      patchelf = tools.patchelf;
      paths = elfPaths;
    })
  ];
  tvp = {
    reportedVersion = final.installedInterface.reportedVersion;
    features = builtins.removeAttrs final.installedInterface [
      "libraryVersion"
      "reportedVersion"
    ];
  };
  meta = {
    description = "Lossless data-compression library implementing the DEFLATE algorithm";
    homepage = "https://zlib.net/";
    license = lib.licenses.zlib;
  };
}

# Zlib 1.2.10–1.2.11: handwritten configure honors the explicit selected CC. Independent upstream checkpoint.
{
  tvp,
  lib,
  base,
  src,
  version,
  doCheck ? true,
  cStandard ? null,
  cFlags ? [ ],
  configureFlags ? [ "--shared" ],
  patches ? [ ],
  bindLowercaseCc ? false,
}:
final:
let
  context = tvp.builder.forBase final.base;
  inherit (context) steps outputs tools;
  environment = final.base.environment final.environment;
  command = steps.command {
    environment = final.environment;
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
    run = ''${tools.python}/bin/python3 -B ${../ordinary-compression-rpaths.py} "$out" ${
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
  inherit bindLowercaseCc;
  inherit (tools) bash coreutils;
  buildFeatures = {
    cStandard = final.cStandard;
  };
  installedInterface = {
    libraryVersion = final.version;
    reportedVersion = final.version;
    libName = "z";
    versionFunction = true;
    compress2 = true;
    pkgConfig = true;
    static = true;
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
      run = "${tools.python}/bin/python3 -B ${../ordinary-compression-production.py} zlib ${tools.bash}/bin/bash ${../compression-source-tree.py}";
    }
    (command "zlib.configure" ''
      ${lib.optionalString (final.cStandard != null || final.cFlags != [ ])
        ''export CFLAGS="''${CFLAGS--O3} ${
          lib.optionalString (final.cStandard != null) "-std=${final.cStandard}"
        } ${lib.escapeShellArgs final.cFlags}"''
      }
      ${lib.optionalString final.bindLowercaseCc ''cc="$CC"''} ./configure --prefix="$out" ${lib.escapeShellArgs final.configureFlags}
    '')
    (command "zlib.build" "${make} libz.a libz.so.${final.installedInterface.libraryVersion}")
    (command "zlib.install" ''
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
    (steps.restoreCheckpoint {
      name = "zlib.restore-build-tree";
      checkpoint = "${artifact}/${checkpoint}";
    })
  ];
  upstreamCheck =
    (command "zlib.check" ''
      export LD_LIBRARY_PATH="$PWD:''${LD_LIBRARY_PATH-}"
      status=0
      # Upstream example variants share foo.gz. Compile in parallel, test in order.
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
      run = ''${tools.python}/bin/python3 -B ${../ordinary-compression-output.py} "$out" "$TVP_ARTIFACT_ROOT" ${tools.patchelf}/bin/patchelf ${
        lib.escapeShellArg (
          builtins.toJSON {
            family = "zlib";
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
    (outputs.stripArchives { paths = [ "lib/libz.a" ]; })
    rpaths
    (outputs.development { libraries = [ ]; })
    {
      name = "output.manuals";
      tools = [ tools.gzip ];
      run = ''${tools.gzip}/bin/gzip -n -9 "$out/share/man/man3/zlib.3"'';
    }
    (outputs.checkSymlinks {
      paths = [
        "lib/libz.so"
        "lib/libz.so.1"
      ];
    })
    (outputs.checkPaths { paths = elfPaths; })
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

# Native 0.19 boundary: explicit source-epoch Findutils on the source-GNU base.
# Shared/static, app, pointer, patch and CTest options retain upstream defaults.
{
  tvp,
  lib,
  base,
  src,
  version,
  patches,
  binutils,
  doCheck ? true,
}@args:

final:
let
  inherit (final)
    base
    src
    version
    patches
    bash
    coreutils
    cmake
    gnumake
    gnutar
    findutils
    gzip
    patch
    sed
    diffutils
    python
    binutils
    patchelf
    ;
  context = tvp.builder.forBase final.base;
  inherit (context) steps outputs;
  baseTools = context.tools;
  elfPaths = [ "lib/libjson-c.so.5.5.0" ];
  environment = final.base.environment final.environment;
in
{
  pname = "json-c";
  bash = baseTools.bash;
  coreutils = baseTools.coreutils;
  gnumake = baseTools.gnumake;
  gnutar = baseTools.gnutar;
  gzip = baseTools.gzip;
  patch = baseTools.patch;
  cmake = baseTools.cmake;
  sed = baseTools.sed;
  diffutils = baseTools.diffutils;
  findutils = baseTools.findutils;
  python = baseTools.python;
  patchelf = baseTools.patchelf;

  inherit (args)
    base
    src
    version
    patches
    binutils
    ;
  inherit doCheck;
  environment = {
    tools = [
      cmake
      gnumake
      sed
      diffutils
    ];
    libraries = [ ];
  };
  cmakeOptions = {
    sourceDirectory = "source";
    buildDirectory = "build";
    cmakeFlags = [ ];
    checkFlags = [ ];
  };
  runtime = {
    libraries = [ ];
    dlopenDirectories = [ ];
  };
  upstreamCheck =
    (
      environment
      // {
        name = "json-c.upstream";
        run = ''
          export TVP_PRODUCTION_ARTIFACT=$(cat "$TVP_SOURCE_ROOT/production-artifact")
          cd "$(cat "$TVP_SOURCE_ROOT/workspace-path")"
          sourceDirectory=${lib.escapeShellArg final.cmakeOptions.sourceDirectory}
          buildDirectory=${lib.escapeShellArg final.cmakeOptions.buildDirectory}
          (cd "$sourceDirectory"; ${
            lib.concatMapStringsSep "\n" (
              p: "${baseTools.patch}/bin/patch -p1 < ${lib.escapeShellArg (toString p)}"
            ) final.testPatches
          })
          ${baseTools.cmake}/bin/cmake -S "$sourceDirectory" -B "$buildDirectory" -G 'Unix Makefiles' \
            -DCMAKE_MAKE_PROGRAM=${lib.escapeShellArg "${baseTools.gnumake}/bin/make"} -DCMAKE_INSTALL_PREFIX="$TVP_PRODUCTION_ARTIFACT" \
            -DCMAKE_INSTALL_LIBDIR=lib -DCMAKE_BUILD_TYPE=Release -DCMAKE_FIND_USE_PACKAGE_REGISTRY=OFF \
            -DCMAKE_FIND_USE_SYSTEM_PACKAGE_REGISTRY=OFF ${lib.escapeShellArgs final.cmakeOptions.cmakeFlags} -DBUILD_TESTING=ON
          ${baseTools.cmake}/bin/cmake --build "$buildDirectory" --parallel "$NIX_BUILD_CORES"
          ${baseTools.cmake}/bin/ctest --test-dir "$buildDirectory" --output-on-failure -j "$NIX_BUILD_CORES" ${lib.escapeShellArgs final.cmakeOptions.checkFlags}
        '';
      }
    )
    // {
      enabled = final.doCheck;
    };
  # Only the source-bound CLI fixture patch is deferred to upstream tests.
  productionPatches = lib.filter (
    p: toString p != toString ./patches/posix-test-byte.patch
  ) final.patches;
  testPatches = lib.filter (p: toString p == toString ./patches/posix-test-byte.patch) final.patches;
  originalPlan = steps.sequence [
    (steps.unpack {
      src = final.src;
      inherit gzip findutils;
      tar = gnutar;
      compression = "gzip";
    })
    {
      name = "source.patch";
      cwd = "source";
      tools = [ patch ];
      run = lib.concatMapStringsSep "\n" (
        p: "${patch}/bin/patch -p1 < ${lib.escapeShellArg "${p}"}"
      ) final.productionPatches;
    }
    (
      (steps.shebangs {
        name = "source.prepare-tests";
        inherit python;
        paths = [ "tests" ];
        names = [
          "sh"
          "bash"
        ];
        interpreter = "${bash}/bin/bash";
      })
      // {
        enabled = final.doCheck;
      }
    )
    (steps.cmake (
      final.cmakeOptions
      // {
        name = "json-c";
        inherit cmake;
        doCheck = false;
        cmakeFlags = final.cmakeOptions.cmakeFlags ++ [ "-DBUILD_TESTING=OFF" ];
        make = gnumake;
        inherit (environment) tools libraries env;
      }
    ))
    {
      name = "json-c.epoch";
      run = ''
        mkdir -p "$out/nix-support"
        cp source-date-epoch "$out/nix-support/source-date-epoch"
      '';
    }
    (steps.split "json-c.finalize")
    (outputs.copyArtifacts { inherit coreutils; })
    (outputs.relocateText {
      inherit python;
      paths = [ "lib/pkgconfig/json-c.pc" ];
    })
    (outputs.strip {
      inherit python binutils;
      paths = elfPaths;
    })
    (outputs.stripArchives {
      inherit python binutils;
      paths = [ "lib/libjson-c.a" ];
    })
    (outputs.rpaths {
      inherit python binutils patchelf;
      base = final.base;
      paths = elfPaths;
      libraries = final.runtime.libraries;
      inherit (final.runtime) dlopenDirectories;
    })
    (outputs.development {
      inherit python;
      libraries = [ ];
    })
    (outputs.checkSymlinks {
      inherit python;
      paths = [
        "lib/libjson-c.so"
        "lib/libjson-c.so.5"
      ];
    })
    (outputs.checkPaths {
      inherit python binutils patchelf;
      paths = elfPaths;
    })
  ];
  tvp.features = {
    doCheck = final.doCheck;
    shared = true;
    static = true;
    jsonPointer = true;
    jsonPatch = true;
    installedCLI = false;
  };
  meta = {
    description = "JSON parser, serializer and reference-counted object library in C";
    homepage = "https://github.com/json-c/json-c";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
  };
  upstreamPlan = artifact: [
    {
      name = "json-c.restore-build-tree";
      tools = [ baseTools.python ];
      run = ''
        ${baseTools.python}/bin/python3 -B ${../../../lib/utilities-checkpoint.py} restore ${artifact}/nix-support/json-c-build-tree "$TVP_SOURCE_ROOT"
        printf '%s\n' ${artifact} > "$TVP_SOURCE_ROOT/production-artifact"
      '';
    }
    {
      name = "json-c.upstream-frontends";
      tools = [ baseTools.python ];
      run = ''
        cd "$(cat "$TVP_SOURCE_ROOT/workspace-path")/${final.cmakeOptions.sourceDirectory}"
        ${(steps.shebangs {
          name = "json-c.test-shells";
          python = baseTools.python;
          paths = [ "tests" ];
          names = [
            "sh"
            "bash"
          ];
          interpreter = "${final.bash}/bin/bash";
        }).run
        }
      '';
    }
  ];
  plan =
    let
      parts = steps.partition final.originalPlan;
      production =
        builtins.filter
          (
            step:
            !(builtins.elem step.name [
              "source.prepare-tests"
              "json-c.check"
            ])
          )
          (builtins.filter (step: step.name != "source.patch" || final.productionPatches != [ ]) parts.first);
    in
    production
    ++ [
      {
        name = "json-c.save-build-tree";
        tools = [
          baseTools.python
          final.coreutils
        ];
        run = ''
          sourcePath=$(${final.coreutils}/bin/realpath "$TVP_SOURCE_ROOT/${final.cmakeOptions.sourceDirectory}")
          buildPath=$(${final.coreutils}/bin/realpath "$TVP_SOURCE_ROOT/${final.cmakeOptions.buildDirectory}")
          ${baseTools.python}/bin/python3 -B ${../../../lib/utilities-checkpoint.py} save "$TVP_SOURCE_ROOT" "$out/nix-support/json-c-build-tree" "[\"$sourcePath\",\"$buildPath\"]" "$buildPath"
        '';
      }
    ]
    ++ (lib.optional parts.split (steps.split "json-c.finalize"))
    ++ [
      (builtins.head parts.second)
      {
        name = "json-c.drop-build-tree";
        tools = [ final.coreutils ];
        run = ''${final.coreutils}/bin/rm -rf -- "$out/nix-support/json-c-build-tree"'';
      }
    ]
    ++ builtins.tail parts.second;

}

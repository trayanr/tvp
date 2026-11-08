{ pkgs, tvp }:
let
  inherit (pkgs) lib;
  inherit (tvp.builder) steps;
  base = tvp.bases.default;
  p = tvp.canonical.json-c_0_19;
  pilot = tvp.variants.build-steps.json-c_0_19;
  inherit (tvp.packages) bash coreutils;
  lookup = base.stdenv.mkDerivation {
    name = "json-c-lookup-directory";
    buildCommand = ''mkdir -p "$out/lib"; touch "$out/lib/lookup-marker"'';
  };
  runtime = p.editRuntime (r: r // { dlopenDirectories = [ "${lookup}/lib" ]; });
  runtimeLibraries = p.editRuntime (r: r // { libraries = [ lookup ]; });
  customRuntime = (p.editRuntime (r: r // { message = "selected"; })).edit (
    s:
    s
    // {
      plan = s.plan ++ [
        {
          name = "fixture.runtime-message";
          run = ''printf '%s' ${lib.escapeShellArg s.runtime.message} > "$out/runtime-message"'';
        }
      ];
    }
  );
  disabled = (p.override { doCheck = false; }).editSteps (
    steps.replace "json-c.check" (
      old:
      old
      // {
        tools = throw "disabled check tools";
        libraries = throw "disabled check libraries";
        env = throw "disabled check environment";
        run = throw "disabled check command";
      }
    )
  );
  insert = steps.insertAfter "json-c.build" [
    {
      name = "fixture.log";
      run = ":";
    }
  ];
  ordered = (p.editSteps insert).editRuntime (r: r);
  tagged = tvp.lib.packages.withConstraint {
    reason = "JSON-C contract fixture.";
  } tvp.packages.json-c_0;
  taggedEdit = tagged.editRuntime (r: r);
  provider = base.environment {
    tools = [ p.tvp.deps.cmake ];
    libraries = [ p ];
  };
  pkgProvider = base.environment {
    tools = [ tvp.packages.pkg-config ];
    libraries = [ p ];
  };
  rejects = x: !(builtins.tryEval (builtins.deepSeq x true)).success;
  supportInputs = {
    json = p;
    inherit (tvp.packages)
      bash
      coreutils
      cmake
      gnumake
      pkg-config
      ;
    patchelf = tvp.packages.patchelf_0;
    environment = base.stdenv;
    compiler = base.stdenv.cc;
  };
  supportRows = builtins.filter (
    row: row.scope == "build-test-support" && row.consumer == "owned-json-c"
  ) tvp.dependencyInventory.support;
  contracts = {
    inventorySupport =
      builtins.length supportRows == builtins.length (builtins.attrNames supportInputs)
      && builtins.all (
        r:
        r.resolved.drv == supportInputs.${r.dependency}.drvPath
        && r.resolved.out == supportInputs.${r.dependency}.outPath
      ) supportRows;
    sameRecipe = p.drvPath == pilot.drvPath && p.artifact.drvPath == pilot.artifact.drvPath;
    source = p.src.drvPath == pilot.src.drvPath;
    split = (steps.partition p.buildSteps).split;
    runtimeArtifact = p.artifact.drvPath == runtime.artifact.drvPath && p.drvPath != runtime.drvPath;
    noFictitiousRuntime = p.runtime.libraries == [ ] && p.development.libraries == [ ];
    runtimeLibraryArtifact =
      p.artifact.drvPath == runtimeLibraries.artifact.drvPath && p.drvPath != runtimeLibraries.drvPath;
    customRuntime =
      p.artifact.drvPath == customRuntime.artifact.drvPath && p.drvPath != customRuntime.drvPath;
    cmakeDiscovery =
      provider.env.CMAKE_PREFIX_PATH == "${lib.getDev p}:${lib.getDev base.stdenv.cc.libc}";
    pkgConfigCompatible =
      pkgProvider.env.PKG_CONFIG_LIBDIR == "${p}/lib/pkgconfig:${p}/share/pkgconfig";
    noOp = (p.override { }).drvPath == p.drvPath && (p.editSteps (x: x)).drvPath == p.drvPath;
    functionOverride =
      (disabled.override (args: {
        doCheck = args.doCheck;
      })).drvPath == disabled.drvPath;
    orderedReplay =
      (ordered.override { doCheck = false; }).drvPath
      == (((p.override { doCheck = false; }).editSteps insert).editRuntime (r: r)).drvPath;
    orderedSpec =
      ((p.edit (s: s // { meta.description = "first"; })).edit (
        s: s // { meta.description = s.meta.description + " second"; }
      )).meta.description == "first second";
    environmentEdit =
      (p.edit (
        s:
        s
        // {
          environment = s.environment // {
            overrides.values.JSON_C_ENVIRONMENT = "selected";
          };
        }
      )).artifact.drvPath != p.artifact.drvPath;
    disabledLazy =
      !(lib.any (s: s.name == "json-c.check" || s.name == "source.prepare-tests") (
        steps.active (steps.partition disabled.buildSteps).first
      ));
    helperLazy =
      builtins.length (
        steps.active (
          steps.cmake {
            name = "lazy";
            cmake = p.tvp.deps.cmake;
            make = p.tvp.deps.gnumake;
            doCheck = false;
            checkFlags = throw "disabled CTest flags";
          }
        )
      ) == 3;
    optionEdits =
      (disabled.edit (
        s:
        s
        // {
          cmakeOptions = s.cmakeOptions // {
            checkFlags = throw "disabled recipe CTest flags";
          };
        }
      )).drvPath == disabled.drvPath;
    noOverrideAttrs = !(p ? overrideAttrs) && !(p ? withBuildSteps);
    unknownRejected = rejects (p.override { unknown = true; }).drvPath;
    noSetup =
      !lib.any
        (
          word:
          lib.hasInfix word (
            lib.concatStrings (p.buildStepRunner.childScripts ++ p.artifact.buildStepRunner.childScripts)
          )
        )
        [
          "/setup"
          "addToSearchPath"
          "runHook"
          "configurePhase"
          "fixupPhase"
          "patchShebangs"
          "updateSourceDateEpoch"
          "genericBuild"
        ];
    testsRebound = runtime.tests.public-api.drvPath != p.tests.public-api.drvPath;
    projections = lib.all (q: q.tests.public-api.drvPath == runtime.tests.public-api.drvPath) (
      [
        runtime.out
        runtime.passthru
      ]
      ++ runtime.all
    );
    testFactory =
      p ? mkTests
      && p.mkTests ? override
      && builtins.isString ((p.mkTests.override { inherit pkgs; }) runtime).public-api.drvPath;
    provenance = runtime.tvp.customization.customized && runtime.__tvpSelection.kind == "override";
    tags =
      lib.all
        (
          q: q.__tvpSelection.selector == "json-c_0" && q.__tvpSelection.reason == "JSON-C contract fixture."
        )
        (
          [
            taggedEdit
            taggedEdit.out
          ]
          ++ taggedEdit.all
        );
    defaults =
      p.tvp.features.shared
      && p.tvp.features.static
      && p.tvp.features.jsonPointer
      && p.tvp.features.jsonPatch
      && !p.tvp.features.installedCLI;
    cmakeProjections = lib.all (q: q ? buildEnvironment) (
      [
        tvp.packages.cmake
        tvp.packages.cmake.out
        (tvp.packages.cmake.override { })
        (tvp.packages.cmake.edit (spec: spec))
      ]
      ++ tvp.packages.cmake.all
    );
  };
  consumer = tvp.builder {
    recipe =
      {
        base,
        bash,
        coreutils,
        json,
        cmake,
        make,
        pkgConfig,
        patchelf,
        version,
        src,
      }:
      {
        pname = "owned-json-c-consumer";
        inherit
          base
          bash
          coreutils
          version
          src
          ;
        plan = [
          (
            (base.environment {
              tools = [
                cmake
                make
                pkgConfig
                patchelf
              ];
              libraries = [ json ];
            })
            // {
              name = "consumer.public";
              run = ''
                mkdir source
                cat > source/CMakeLists.txt <<'CMAKE'
                cmake_minimum_required(VERSION 3.16)
                project(json_c_consumer C)
                find_package(json-c CONFIG REQUIRED)
                add_executable(shared ${../../pkgs/libraries/json-c/tests/fixtures/api.c})
                target_link_libraries(shared PRIVATE json-c::json-c)
                add_executable(archive ${../../pkgs/libraries/json-c/tests/fixtures/api.c})
                target_link_libraries(archive PRIVATE json-c::json-c-static m)
                CMAKE
                ${cmake}/bin/cmake -S source -B build -G 'Unix Makefiles' \
                  -DCMAKE_MAKE_PROGRAM=${make}/bin/make \
                  -DCMAKE_FIND_USE_PACKAGE_REGISTRY=OFF -DCMAKE_FIND_USE_SYSTEM_PACKAGE_REGISTRY=OFF
                ${cmake}/bin/cmake --build build --parallel "$NIX_BUILD_CORES"
                test "$($PKG_CONFIG --variable=prefix json-c)" = ${json}
                test "$($PKG_CONFIG --modversion json-c)" = ${json.version}
                "$CC" $($PKG_CONFIG --cflags json-c) ${../../pkgs/libraries/json-c/tests/fixtures/api.c} $($PKG_CONFIG --libs json-c) -o pc-shared
                "$CC" $($PKG_CONFIG --cflags json-c) ${../../pkgs/libraries/json-c/tests/fixtures/api.c} ${json}/lib/libjson-c.a -lm -o pc-static
                for binary in build/shared build/archive pc-shared pc-static; do
                  test "$(env -i ./$binary)" = ok
                done
                env -i LD_DEBUG=libs ./build/shared > /dev/null 2> loader
                grep -F 'calling init: ${json}/lib/libjson-c.so.5' loader
                test ! -d ${json}/bin
                test -s ${json}/nix-support/source-date-epoch
                test ! -s ${json}/nix-support/propagated-build-inputs
                ${patchelf}/bin/patchelf --print-rpath ${json}/lib/libjson-c.so.5 > lookup
                ${lib.optionalString (json.drvPath == runtime.drvPath) ''
                  grep -F '${lookup}/lib' lookup
                ''}
                mkdir "$out"
                cp loader lookup pc-shared pc-static "$out/"
                cp build/shared build/archive "$out/"
              '';
            }
          )
        ];
      };
    args = {
      inherit base bash coreutils;
      json = p;
      inherit (p.tvp.deps) cmake patchelf;
      make = p.tvp.deps.gnumake;
      pkgConfig = tvp.packages.pkg-config;
      src = null;
      version = "1";
    };
    dependencyNames = [
      "json"
      "cmake"
      "make"
      "pkgConfig"
      "patchelf"
    ];
    metadata = { };
    selection.kind = "fixture";
    mkTests = _: { };
  };
  runtimeConsumer = consumer.override { json = runtime; };
  traceTool =
    binary: original:
    (base.stdenv.mkDerivation {
      name = "json-c-selected-${binary}";
      buildCommand =
        ''mkdir -p "$out/bin"''
        + "\n"
        + lib.concatMapStringsSep "\n" (program: ''
          cat > "$out/bin/${program}" <<'SCRIPT'
          #!${bash}/bin/bash
          printf '%s\n' "${program} $*" >> "$NIX_BUILD_TOP/selected-tools"
          exec ${original}/bin/${program} "$@"
          SCRIPT
          chmod +x "$out/bin/${program}"
        '') ([ binary ] ++ lib.optional (binary == "cmake") "ctest");
    })
    // lib.optionalAttrs (original ? buildEnvironment) { inherit (original) buildEnvironment; };
  selected =
    (
      (p.edit (
        s:
        s
        // {
          cmakeOptions = s.cmakeOptions // {
            buildDirectory = "selected-build";
            cmakeFlags = [ "-DCMAKE_EXPORT_COMPILE_COMMANDS=ON" ];
          };
        }
      )).override
      {
        cmake = traceTool "cmake" p.tvp.deps.cmake;
        gnumake = traceTool "make" p.tvp.deps.gnumake;
      }
    ).editSteps
      (
        steps.insertBefore "json-c.finalize" [
          {
            name = "fixture.selected-tools";
            run = ''
              test -s selected-build/compile_commands.json
              grep -F 'cmake -S source -B selected-build' "$NIX_BUILD_TOP/selected-tools"
              grep -F 'cmake --build selected-build --parallel' "$NIX_BUILD_TOP/selected-tools"
              grep -F 'cmake --build selected-build --target install' "$NIX_BUILD_TOP/selected-tools"
              grep -F 'ctest --test-dir selected-build' "$NIX_BUILD_TOP/selected-tools"
              grep -E '^make .*' "$NIX_BUILD_TOP/selected-tools"
              # Full invocations stay in the build log: their artifact prefix must
              # never enter the final output. Export only the verified operations.
              printf '%s\n' cmake-configure cmake-build cmake-install ctest make > "$out/selected-tools"
            '';
          }
        ]
      );
  failed = lib.filter (n: !contracts.${n}) (lib.attrNames contracts);
in
assert failed == [ ] || throw "Owned JSON-C contracts: ${lib.concatStringsSep ", " failed}";
(base.stdenv.mkDerivation {
  name = "tvp-owned-json-c-contracts";
  buildCommand = ''
    test -s ${selected}/selected-tools
    test -x ${consumer}/shared
    test -x ${runtimeConsumer}/shared
    test -e ${disabled}/lib/libjson-c.a
    ${p.tvp.deps.patchelf}/bin/patchelf --print-rpath ${runtimeLibraries}/lib/libjson-c.so.5 | grep -F '${lookup}/lib'
    test "$(cat ${customRuntime}/runtime-message)" = selected
    printf '%s\n' '${builtins.toJSON contracts}' > "$out"
  '';
})
// {
  passthru = {
    inherit
      contracts
      consumer
      runtime
      runtimeLibraries
      customRuntime
      runtimeConsumer
      selected
      disabled
      lookup
      ;
  };
}

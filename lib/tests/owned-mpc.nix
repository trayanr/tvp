{ pkgs, tvp }:
let
  inherit (pkgs) lib;
  inherit (tvp.builder) steps;
  base = tvp.bases.default;
  p = tvp.canonical.mpc_1_4_1;
  compatibleMpfr = tvp.packages.mpfr_4_2_1;
  inherit (tvp.packages) bash coreutils pkg-config;
  family = (import ../../pkgs/libraries/mpc { inherit pkgs tvp; }).recipes.mpc;
  legacy = (tvp.lib.packages.mkVersions family.constructionRecipe).mpc_1_4_1;
  lookup = base.stdenv.mkDerivation {
    name = "mpc-lookup-directory";
    buildCommand = ''mkdir -p "$out/lib" "$out/plugins"; touch "$out/lib/lookup-marker"'';
  };
  runtime = p.editRuntime (
    r:
    r
    // {
      libraries = [
        p.tvp.deps.gmp
        compatibleMpfr
      ];
    }
  );
  extended = p.editRuntime (
    r:
    r
    // {
      libraries = r.libraries ++ [ lookup ];
      dlopenDirectories = [ "${lookup}/plugins" ];
    }
  );
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
    steps.replace "mpc.check" (
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
  insert = steps.insertAfter "mpc.build" [
    {
      name = "fixture.log";
      run = ":";
    }
  ];
  ordered = (p.editSteps insert).editRuntime (r: r);
  tagged =
    (tvp.lib.packages.withConstraint {
      reason = "MPC contract fixture.";
    } tvp.packages.mpc_1).editRuntime
      (r: r);
  provider = base.environment {
    tools = [ pkg-config ];
    libraries = [ p ];
  };
  supportInputs = {
    mpc = p;
    inherit
      compatibleMpfr
      bash
      coreutils
      pkg-config
      ;
    gnumake = p.tvp.deps.gnumake;
    patchelf = p.tvp.deps.patchelf;
    environment = base.stdenv;
    compiler = base.stdenv.cc;
  };
  supportRows = builtins.filter (
    r: r.scope == "build-test-support" && r.consumer == "owned-mpc"
  ) tvp.dependencyInventory.support;
  contracts = {
    inventorySupport =
      builtins.length supportRows == builtins.length (builtins.attrNames supportInputs)
      && builtins.all (
        r:
        r.resolved.drv == supportInputs.${r.dependency}.drvPath
        && r.resolved.out == supportInputs.${r.dependency}.outPath
      ) supportRows;
    split = (steps.partition p.buildSteps).split;
    sourceArchiveHash = p.src.outputHash == legacy.src.outputHash;
    sourceProducer = p.src.drvPath != legacy.src.drvPath;
    legacy = legacy ? overrideAttrs && !(legacy ? edit) && tvp.canonical.mpc_1_4_0 ? overrideAttrs;
    oldConstraint = tvp.canonical.mpc_1_0_3.tvp.deps.mpfr.version == "3.1.6";
    runtimeArtifact = p.artifact.drvPath == runtime.artifact.drvPath && p.drvPath != runtime.drvPath;
    compileInputs =
      p.specification.environment.libraries == runtime.specification.environment.libraries;
    publicRequirements =
      map toString p.development.libraries == map toString [
        p.tvp.deps.gmp
        p.tvp.deps.mpfr
      ];
    runtimePublic = map toString runtime.development.libraries == map toString p.development.libraries;
    publicDiscovery =
      lib.all
        (
          q:
          lib.hasInfix (builtins.unsafeDiscardStringContext "${lib.getDev q}/lib/pkgconfig") provider.env.PKG_CONFIG_LIBDIR
        )
        [
          p
          p.tvp.deps.mpfr
          p.tvp.deps.gmp
        ];
    noBuildToolsExported =
      map toString provider.libraries == map toString [
        p
        p.tvp.deps.gmp
        p.tvp.deps.mpfr
      ];
    selectedPkgConfig = provider.env.PKG_CONFIG == "${pkg-config}/bin/pkg-config";
    noAmbient = provider.env.PKG_CONFIG_PATH == "" && provider.env.PKG_CONFIG_SYSROOT_DIR == "";
    extensible =
      p.artifact.drvPath == extended.artifact.drvPath
      && p.drvPath != extended.drvPath
      && p.artifact.drvPath == customRuntime.artifact.drvPath;
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
            overrides.values.MPC_ENVIRONMENT = "selected";
          };
        }
      )).artifact.drvPath != p.artifact.drvPath;
    disabledLazy =
      !(lib.any (s: s.name == "mpc.check") (steps.active (steps.partition disabled.buildSteps).first));
    noOverrideAttrs = !(p ? overrideAttrs);
    unknownRejected = !(builtins.tryEval (p.override { unknown = true; }).drvPath).success;
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
          "runHook"
          "genericBuild"
          "fixupPhase"
          "patchShebangs"
          "fixLibtool"
          "updateSourceDateEpoch"
        ];
    testsRebound = runtime.tests.arithmetic.drvPath != p.tests.arithmetic.drvPath;
    projections = lib.all (q: q.tests.arithmetic.drvPath == runtime.tests.arithmetic.drvPath) (
      [
        runtime.out
        runtime.passthru
      ]
      ++ runtime.all
    );
    testFactory =
      p.mkTests ? override
      &&
        ((p.mkTests.override { inherit pkgs; }) runtime).arithmetic.drvPath
        == runtime.tests.arithmetic.drvPath;
    provenance = runtime.tvp.customization.customized && runtime.__tvpSelection.kind == "override";
    tags =
      lib.all
        (q: q.__tvpSelection.selector == "mpc_1" && q.__tvpSelection.reason == "MPC contract fixture.")
        (
          [
            tagged
            tagged.out
          ]
          ++ tagged.all
        );
    defaults = p.tvp.features.shared && !p.tvp.features.static;
  };
  consumer = tvp.builder {
    recipe =
      {
        base,
        bash,
        coreutils,
        mpc,
        pkgConfig,
        patchelf,
        version,
        src,
      }:
      {
        pname = "owned-mpc-consumer";
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
                pkgConfig
                patchelf
              ];
              libraries = [ mpc ];
            })
            // {
              name = "consumer.public";
              run = ''
                test "$($PKG_CONFIG --variable=prefix mpc)" = ${mpc}
                test "$($PKG_CONFIG --modversion mpc)" = ${mpc.version}
                test "$($PKG_CONFIG --modversion mpfr)" = ${p.tvp.deps.mpfr.version}
                $PKG_CONFIG --print-requires-private mpc > requirements
                grep -F 'mpfr >= 4.1.0' requirements
                grep -F 'gmp >= 5.0.0' requirements
                $PKG_CONFIG --static --libs mpc > private-libs
                grep -F -- -lmpfr private-libs
                grep -F -- -lgmp private-libs
                # Public interface discovers both transitive headers without explicit dependency arguments.
                "$CC" ${../../pkgs/libraries/mpc/tests/fixtures/arithmetic.c} -lmpc -lmpfr -lgmp -o direct
                test "$(env -i ./direct)" = 25
                env -i LD_DEBUG=libs ./direct > /dev/null 2> direct-loader
                # Direct MPFR DT_NEEDED wins the executable's same-SONAME lookup.
                grep -F 'calling init: ${p.tvp.deps.mpfr}/lib/libmpfr.so.6' direct-loader
                "$CC" $($PKG_CONFIG --cflags mpc) ${../../pkgs/libraries/mpc/tests/fixtures/owned.c} $($PKG_CONFIG --libs mpc) -o numeric
                ${patchelf}/bin/patchelf --print-needed numeric > needed
                grep -x libmpc.so.3 needed
                ! grep -E '^lib(mpfr|gmp)\.so' needed
                # Remove compile-interface MPFR/GMP search directories from this MPC-only executable.
                ${patchelf}/bin/patchelf --shrink-rpath numeric
                test "$(env -i ./numeric)" = ok
                env -i LD_DEBUG=libs ./numeric > /dev/null 2> loader
                grep -F 'calling init: ${mpc}/lib/libmpc.so.3' loader
                grep -F 'calling init: ${
                  lib.getLib (builtins.elemAt mpc.runtime.libraries 1)
                }/lib/libmpfr.so.6' loader
                grep -F 'calling init: ${p.tvp.deps.gmp}/lib/libgmp.so.10' loader
                test ! -e ${mpc}/lib/libmpc.a
                grep -E "^old_library=.{2}$" ${mpc}/lib/libmpc.la
                test -s ${mpc}/nix-support/source-date-epoch
                mkdir "$out"
                cp numeric direct loader direct-loader needed requirements private-libs "$out/"
              '';
            }
          )
        ];
      };
    args = {
      inherit base bash coreutils;
      mpc = p;
      pkgConfig = pkg-config;
      patchelf = p.tvp.deps.patchelf;
      version = "1";
      src = null;
    };
    dependencyNames = [
      "mpc"
      "pkgConfig"
      "patchelf"
    ];
    metadata = { };
    selection.kind = "fixture";
    mkTests = _: { };
  };
  runtimeConsumer = consumer.override { mpc = runtime; };
  selectedMake = base.stdenv.mkDerivation {
    name = "mpc-selected-make";
    buildCommand = ''
      mkdir -p "$out/bin"
      cat > "$out/bin/make" <<'SCRIPT'
      #!${bash}/bin/bash
      printf '%s\n' "$*" >> "$NIX_BUILD_TOP/selected-make"
      exec ${p.tvp.deps.gnumake}/bin/make "$@"
      SCRIPT
      chmod +x "$out/bin/make"
    '';
  };
  selected = (p.override { gnumake = selectedMake; }).editSteps (
    steps.insertBefore "mpc.finalize" [
      {
        name = "fixture.selected-tools";
        run = ''
          grep -E -- '^-j[0-9]+ check$' "$NIX_BUILD_TOP/selected-make"
          grep -E -- '^-j[0-9]+ install$' "$NIX_BUILD_TOP/selected-make"
          grep -F '${p.compiler}/bin/cc' source/config.log
          printf '%s\n' compiler make-build make-check make-install > "$out/selected-tools"
        '';
      }
    ]
  );
  failed = lib.filter (n: !contracts.${n}) (lib.attrNames contracts);
in
assert failed == [ ] || throw "Owned MPC contracts: ${lib.concatStringsSep ", " failed}";
(base.stdenv.mkDerivation {
  name = "tvp-owned-mpc-contracts";
  buildCommand = ''
    test -x ${consumer}/numeric
    test -x ${runtimeConsumer}/numeric
    test -s ${selected}/selected-tools
    test -e ${disabled}/lib/libmpc.so
    ${p.tvp.deps.patchelf}/bin/patchelf --print-rpath ${extended}/lib/libmpc.so.3 | grep -F '${lookup}/lib'
    ${p.tvp.deps.patchelf}/bin/patchelf --print-rpath ${extended}/lib/libmpc.so.3 | grep -F '${lookup}/plugins'
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
      runtimeConsumer
      extended
      customRuntime
      selected
      disabled
      legacy
      lookup
      ;
  };
}

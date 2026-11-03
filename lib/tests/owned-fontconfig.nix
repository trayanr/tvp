{ pkgs, tvp }:
let
  inherit (pkgs) lib;
  inherit (tvp.builder) steps;
  p = tvp.canonical.fontconfig_2_18_3;
  variant = tvp.variants.build-steps.fontconfig_2_18_3;
  compatible = pkgs.expat;
  substituted = p.editRuntime (
    r:
    r
    // {
      libraries = [
        p.tvp.deps.freetype
        compatible
      ];
    }
  );
  disabled = (p.override { doCheck = false; }).editSteps (
    steps.replace "fontconfig.check" (_: {
      name = "fontconfig.check";
      enabled = false;
      tools = throw "disabled inputs forced";
      run = throw "disabled body forced";
    })
  );
  insert = steps.insertAfter "fontconfig.build" [
    {
      name = "local.probe";
      run = "true";
    }
  ];
  edited = (p.editSteps insert).editRuntime (r: r);
  env = p.specification.base.environment p.specification.environment;
  contracts = {
    sameRecipe = p.drvPath == variant.drvPath;
    zeroSplit = !(steps.partition p.buildSteps).split && !(p ? artifact);
    runtimeRebuilds = p.drvPath != substituted.drvPath && !(substituted ? artifact);
    compileInputsPreserved =
      p.specification.environment.libraries == substituted.specification.environment.libraries;
    runtimeOperation = lib.hasInfix (builtins.unsafeDiscardStringContext (toString compatible)) (
      lib.concatStrings (
        map (s: s.run) (builtins.filter (s: s.name == "output.rpaths") substituted.buildSteps)
      )
    );
    sourcePreserved = p.src.drvPath == variant.src.drvPath;
    noOverrideAttrs = !(p ? overrideAttrs);
    disabledLazy = !(builtins.any (s: s.name == "fontconfig.check") (steps.active disabled.buildSteps));
    checkFeature = !disabled.tvp.features.doCheck && disabled.tvp.features.tests;
    unknownRejected = !(builtins.tryEval (p.override { unknown = true; }).drvPath).success;
    currentArguments =
      (disabled.override (args: {
        doCheck = args.doCheck;
      })).drvPath == disabled.drvPath;
    orderedReplay =
      (edited.override { doCheck = false; }).drvPath
      == (((p.override { doCheck = false; }).editSteps insert).editRuntime (r: r)).drvPath;
    selectedTools = env.env.PKG_CONFIG == "${p.tvp.deps.pkg-config}/bin/pkg-config";
    publicDiscovery =
      lib.hasInfix (builtins.unsafeDiscardStringContext "${p.tvp.deps.freetype}/lib/pkgconfig") env.env.PKG_CONFIG_LIBDIR
      && lib.hasInfix (builtins.unsafeDiscardStringContext "${p.tvp.deps.freetype}/include/freetype2") env.env.NIX_CFLAGS_COMPILE;
    noAmbient = env.env.PKG_CONFIG_PATH == "" && env.env.PKG_CONFIG_SYSROOT_DIR == "";
    testsRebound =
      substituted.tests.consumer.package.outPath == substituted.outPath
      && substituted.tests.consumer.drvPath != p.tests.consumer.drvPath;
    projectionTests =
      substituted.out.tests.consumer.drvPath == substituted.tests.consumer.drvPath
      && (builtins.head substituted.all).tests.consumer.drvPath == substituted.tests.consumer.drvPath;
    passthruTests = substituted.passthru.tests.consumer.drvPath == substituted.tests.consumer.drvPath;
    provenance =
      substituted.tvp.customization.customized
      && substituted.__tvpSelection.kind == "override"
      && substituted.tvp.deps.expat.drvPath == p.tvp.deps.expat.drvPath;
    aliasEdits = (tvp.packages.fontconfig_2.edit (s: s)).__tvpSelection.selector == "fontconfig_2";
    noSetup = !lib.hasInfix "/setup" (lib.concatStrings p.buildStepRunner.childScripts);
  };
  consumer = tvp.builder {
    recipe =
      {
        base,
        bash,
        coreutils,
        fontconfig,
        pkgConfig,
        version,
        src,
      }:
      {
        pname = "owned-fontconfig-consumer";
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
              tools = [ pkgConfig ];
              libraries = [ fontconfig ];
            })
            // {
              name = "consumer.public";
              run = ''
                test "$($PKG_CONFIG --modversion fontconfig)" = ${p.version}
                $PKG_CONFIG --print-requires-private fontconfig > requirements
                grep -F freetype2 requirements
                grep -F expat requirements
                # Check .pc private search requirements, without claiming a static library.
                $PKG_CONFIG --static --libs fontconfig > private-libs
                grep -F -- -lbz2 private-libs
                grep -F -- -lz private-libs
                printf '#include <fontconfig/fontconfig.h>\n#include <fontconfig/fcfreetype.h>\nint main(void) { FT_Library ft; if (FT_Init_FreeType(&ft)) return 1; FT_Done_FreeType(ft); return 0; }\n' > headers.c
                "$CC" headers.c -lfontconfig -lfreetype -o headers
                "$CC" $($PKG_CONFIG --cflags fontconfig) ${../../pkgs/libraries/fontconfig/tests/fixtures/consumer.c} $($PKG_CONFIG --libs fontconfig) -o consumer
                "$CC" $($PKG_CONFIG --cflags fontconfig) ${../../pkgs/libraries/fontconfig/tests/fixtures/default-config.c} $($PKG_CONFIG --libs fontconfig) -o defaults
                mkdir -p "$TMPDIR/home" "$TMPDIR/cache" "$TMPDIR/config" "$TMPDIR/data" "$TMPDIR/runtime"
                env -i ./headers
                env -i ./consumer ${../../pkgs/libraries/fontconfig/tests/fixtures/font.bdf}
                env -i HOME="$TMPDIR/home" XDG_CACHE_HOME="$TMPDIR/cache" XDG_CONFIG_HOME="$TMPDIR/config" XDG_DATA_HOME="$TMPDIR/data" XDG_RUNTIME_DIR="$TMPDIR/runtime" ./defaults ${fontconfig}
                env -i HOME="$TMPDIR/home" XDG_CACHE_HOME="$TMPDIR/cache" ${fontconfig}/bin/fc-conflist > configurations
                grep -F '${fontconfig}/share/fontconfig/conf.avail/' configurations
                # Verify the actual loaded Expat provider through the loader's diagnostics.
                env -i LD_DEBUG=libs ./consumer ${../../pkgs/libraries/fontconfig/tests/fixtures/font.bdf} 2> loader
                grep -F 'calling init: ${
                  lib.getLib (builtins.elemAt fontconfig.runtime.libraries 1)
                }/lib/libexpat.so.1' loader
                mkdir "$out"
                cp consumer headers defaults requirements private-libs configurations loader "$out/"
              '';
            }
          )
        ];
      };
    args = {
      base = tvp.bases.default;
      inherit (tvp.packages) bash coreutils;
      fontconfig = p;
      pkgConfig = tvp.packages.pkg-config;
      version = "1";
      src = null;
    };
    dependencyNames = [
      "fontconfig"
      "pkgConfig"
    ];
    metadata = { };
    selection.kind = "fixture";
    mkTests = _: { };
  };
  runtimeConsumer = consumer.override { fontconfig = substituted; };
  failed = builtins.filter (n: !contracts.${n}) (builtins.attrNames contracts);
in
assert failed == [ ] || throw "Owned Fontconfig contracts: ${lib.concatStringsSep ", " failed}";
(tvp.bases.default.stdenv.mkDerivation {
  name = "tvp-owned-fontconfig-contracts";
  buildCommand = ''
    test -x ${consumer}/consumer
    test -x ${runtimeConsumer}/consumer
    test -e ${substituted.tests.installed}
    printf '%s\n' '${builtins.toJSON contracts}' > "$out"
  '';
})
// {
  passthru = {
    inherit
      contracts
      consumer
      substituted
      runtimeConsumer
      ;
  };
}

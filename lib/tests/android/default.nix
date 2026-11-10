{ pkgs, tvp }:
let
  inherit (pkgs) lib;
  inherit (tvp.builder) steps;
  names = [
    "android-build-tools_37_0_0"
    "android-cli_1_1_16717390"
    "android-commandline-tools_23_0"
    "android-ndk_30_0_16248370"
    "android-platform_37_2_r2"
    "android-platform-tools_37_0_1"
  ];
  components = lib.genAttrs names (n: tvp.canonical.${n});
  profiles = tvp.android.profiles;
  id = p: p.drvPath;
  row = p: builtins.head (tvp.lib.recipeSplits.inventory { canonical.fixture = p; }).rows;
  finalChange =
    p:
    p.editSteps (
      steps.append [
        {
          name = "android.contract-suffix";
          run = ''printf final > "$out/contract"'';
        }
      ]
    );
  sourceChange = p: p.override { src = ./platform.zip; };
  pathChange = p: p.edit (s: s // { sdkPath = "contract/changed"; });
  contracts = {
    components = lib.mapAttrs (_: p: {
      owned = p ? testContext && (row p).compliant;
      disabledTests = (p.edit (s: s // { testsEnabled = false; })).tests == { };
      distinct = id p != id p.artifact;
      stages = (row p).partition.activeBefore > 0 && (row p).partition.activeAfter > 1;
      finalReuse = id (finalChange p).artifact == id p.artifact && id (finalChange p) != id p;
      sourceInvalidates = id (sourceChange p).artifact != id p.artifact;
      testsRebound = lib.all (n: id (finalChange p).tests.${n} != id p.tests.${n}) (
        builtins.attrNames p.tests
      );
      outputExcludesArtifact = builtins.elem (toString p.artifact) (
        map toString p.outputChecks.out.disallowedReferences
      );
    }) components;
    profiles = lib.mapAttrs (_: p: {
      owned = (row p).compliant;
      finalReuse = id (finalChange p).artifact == id p.artifact && id (finalChange p) != id p;
      shellReuse =
        let
          q = p.editRuntime (r: r // { shell = "${p.specification.bash}/bin/sh"; });
        in
        id q.artifact == id p.artifact && id q != id p;
      prefixInvalidates =
        id (pathChange p).artifact != id p.artifact && (pathChange p).sdkPath == "contract/changed";
      componentInvalidates =
        id (p.override { components = [ tvp.canonical.android-platform_36_r2 ]; }).artifact
        != id p.artifact;
      outputExcludesArtifact = builtins.elem (toString p.artifact) (
        map toString p.outputChecks.out.disallowedReferences
      );
    }) profiles;
    finalFields = lib.mapAttrs (
      _: p:
      let
        edit = p.editRuntime (r: r // { loader = "${p.specification.runtimeLibc}/lib/contract-loader"; });
      in
      id edit.artifact == id p.artifact && id edit != id p
    ) (lib.filterAttrs (n: _: n != "android-platform_37_2_r2") components);
    providers = lib.mapAttrs (
      _: p:
      let
        reuse = q: id q.artifact == id p.artifact && id q != id p;
      in
      {
        libraries = reuse (p.editRuntime (r: r // { libraries = [ p.specification.runtimeLibc ]; }));
        loaderProvider = reuse (p.override { runtimeLibc = p.specification.runtimeCompiler; });
        patchTool = reuse (p.override { patchelf = p.specification.coreutils; });
      }
    ) (lib.filterAttrs (n: _: n != "android-platform_37_2_r2") components);
    shell =
      lib.all
        (
          n:
          let
            p = components.${n};
            q = p.editRuntime (r: r // { shell = "${p.specification.bash}/bin/sh"; });
          in
          id q.artifact == id p.artifact && id q != id p
        )
        [
          "android-build-tools_37_0_0"
          "android-commandline-tools_23_0"
          "android-ndk_30_0_16248370"
        ];
    unzipInvalidates = lib.mapAttrs (
      _: p: id (p.override { unzip = p.specification.coreutils; }).artifact != id p.artifact
    ) (lib.filterAttrs (n: _: n != "android-cli_1_1_16717390") components);
    sdkInterfaces = lib.mapAttrs (
      _: p:
      let
        q = pathChange p;
      in
      q.tvp.android.sdkPath == "contract/changed" && id q.artifact != id p.artifact
    ) (lib.filterAttrs (n: _: n != "android-cli_1_1_16717390") components);
    metadataReuse = lib.mapAttrs (
      _: p:
      let
        q = p.override { packageMetadata = builtins.toFile "android-metadata" "changed"; };
      in
      id q.artifact == id p.artifact && id q != id p
    ) (lib.filterAttrs (n: _: n != "android-cli_1_1_16717390") components);
    jdkReuse =
      lib.all
        (
          n:
          let
            p = components.${n};
            q = p.override { jdk = p.specification.bash; };
          in
          id q.artifact == id p.artifact && id q != id p && id q.tests.version != id p.tests.version
        )
        [
          "android-build-tools_37_0_0"
          "android-commandline-tools_23_0"
        ];
    makeReuse =
      let
        p = components.android-ndk_30_0_16248370;
        q = p.override { gnumake = p.specification.coreutils; };
      in
      id q.artifact == id p.artifact && id q != id p;
    errors =
      let
        rejects = args: !(builtins.tryEval (tvp.android.mkSdk args)).success;
        p = tvp.canonical.android-commandline-tools_23_0;
      in
      {
        empty = rejects { components = [ ]; };
        duplicates = rejects {
          components = [
            p
            p
          ];
        };
        multipleCLI = rejects {
          components = [
            p
            (p.edit (s: s // { sdkPath = "cmdline-tools/other"; }))
          ];
        };
      };
  };
  allTrue = x: if builtins.isAttrs x then lib.all allTrue (builtins.attrValues x) else x == true;
  fixture = components.android-platform_37_2_r2.override { src = ./platform.zip; };
  changed = fixture.override {
    packageMetadata = builtins.toFile "fixture-package.xml" "edited-metadata";
  };
  sdk = tvp.android.mkSdk {
    name = "android-tiny-sdk";
    components = [ fixture ];
  };
  sdkChanged = sdk.editRuntime (r: r // { shell = "${sdk.specification.bash}/bin/sh"; });
  spec = fixture.specification;
  check = fixture.testContext.mkTest {
    package = fixture;
    name = "android-contracts";
    tools = [
      spec.coreutils
      spec.diffutils
      spec.grep
      spec.python
      spec.binutils
      spec.patchelf
    ];
    script = ''
      test "$(cat ${fixture}/${fixture.tvp.android.componentPath}/android.jar)" = fixture-jar
      test "$(cat ${changed}/${changed.tvp.android.componentPath}/package.xml)" = edited-metadata
      export XDG_CACHE_HOME="$TMPDIR/cache"
      ${sdk}/bin/tvp-android-sdk > first & first=$!
      ${sdk}/bin/tvp-android-sdk > second & second=$!
      wait "$first"; wait "$second"; cmp first second
      cache=$(cat first)
      test -f "$cache/.tvp-prepared"
      test -L "$cache/platforms/android-37.2"
      test -w "$cache"
      ${sdkChanged}/bin/tvp-android-sdk > changed-cache
      test "$(cat changed-cache)" != "$cache"
      unset XDG_CACHE_HOME
      ${sdk}/bin/tvp-android-sdk > fallback-cache
      test -f "$(cat fallback-cache)/.tvp-prepared"
      # Real latest and Flutter profiles: links, concurrent preparation, exported
      # setup environment and per-output cache separation, without device/network use.
      export XDG_CACHE_HOME="$TMPDIR/profile-cache"
      ${lib.concatMapStringsSep "\n"
        (
          profile:
          let
            sdk = profiles.${profile};
          in
          ''
            ${sdk}/bin/tvp-android-sdk > ${profile}-first & first=$!
            ${sdk}/bin/tvp-android-sdk > ${profile}-second & second=$!
            wait "$first"; wait "$second"
            cmp ${profile}-first ${profile}-second
            cache=$(cat ${profile}-first)
            test -f "$cache/.tvp-prepared"
            ${lib.concatMapStringsSep "\n" (component: ''
              test "$(readlink "$cache/${component.tvp.android.sdkPath}")" = '${component}/${component.tvp.android.componentPath}'
            '') sdk.components}
            test -x "$cache/cmdline-tools/latest/bin/android"
            test -x ${sdk}/bin/adb
            source ${sdk}/nix-support/setup-hook
            test "$ANDROID_HOME" = "$cache"
            test "$ANDROID_SDK_ROOT" = "$cache"
          ''
        )
        [
          "latest"
          "flutter"
        ]
      }
      test "$(cat latest-first)" != "$(cat flutter-first)"
      ${spec.python}/bin/python3 -B ${./host-elf-test.py} ${../../host-elf.py} ${../../native-output} ${spec.coreutils}/bin/true ${spec.binutils}/bin/readelf ${spec.patchelf}/bin/patchelf '${
        builtins.toJSON {
          loader = spec.runtime.loader;
          libraries = map (p: "${lib.getLib p}/lib") spec.runtime.libraries;
        }
      }'
      printf android-contracts-ok
    '';
    expected = "android-contracts-ok";
  };
in
assert allTrue contracts || throw "Android boundary contracts failed: ${builtins.toJSON contracts}";
check
// {
  passthru = {
    inherit
      contracts
      fixture
      changed
      sdk
      sdkChanged
      ;
  };
}

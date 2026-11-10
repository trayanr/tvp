# Focused staging entry point, deliberately separate from installed Dart/Flutter
# controls. `contracts` is pure; `runtime` builds only a tiny cached-LLVM ELF.
{ pkgs, tvp }:
let
  inherit (pkgs) lib;
  inherit (tvp.builder) steps outputs;
  p = tvp.canonical;
  dart = p.dart_3_13_7;
  flutter = p.flutter_3_47_8;
  stable = p.dart-bootstrap_3_13_7;
  sourceEdit =
    package: package.edit (s: s // { src = builtins.toFile "sdk-stage-source-edit" "changed source"; });
  finalEdit =
    package:
    package.editRuntime (
      r: r // { loader = "${dart.specification.llvm.tvp.deps.libc}/lib/ld-linux-x86-64.so.2.stage-edit"; }
    );
  suffixEdit =
    package:
    package.editSteps (
      steps.append [
        {
          name = "stage.final-edit";
          run = ": final-edit";
        }
      ]
    );
  prefixEdit =
    package:
    package.editSteps (
      steps.insertBefore (builtins.head package.buildSteps).name [
        {
          name = "stage.prefix-edit";
          run = ": prefix-edit";
        }
      ]
    );
  stableArtifact = a: b: a.artifact.drvPath == b.artifact.drvPath && a.drvPath != b.drvPath;
  changedArtifact = a: b: a.artifact.drvPath != b.artifact.drvPath;
  environment = (builtins.head (builtins.filter (s: s.name == "dart.configure") dart.buildSteps)).env;
  partition = steps.partition flutter.buildSteps;
  rejects = x: !(builtins.tryEval (builtins.deepSeq x true)).success;
  contractValues = {
    splits = builtins.all (x: x.artifact.drvPath != x.drvPath && (steps.partition x.buildSteps).split) [
      stable
      dart
      flutter
    ];
    finalEdits = builtins.all (x: stableArtifact x (finalEdit x)) [
      stable
      dart
      flutter
    ];
    sourceEdits = builtins.all (x: changedArtifact x (sourceEdit x)) [
      stable
      dart
      flutter
    ];
    stepEdits = builtins.all (x: stableArtifact x (suffixEdit x) && changedArtifact x (prefixEdit x)) [
      stable
      dart
      flutter
    ];
    overrides = stableArtifact dart (
      dart.override { dynamicLinker = "${dart.specification.llvm.tvp.dynamicLinker}.override"; }
    );
    flutterDartFinalOnly = stableArtifact flutter (flutter.override { dart = stable; });
    flutterJdkFinalOnly = stableArtifact flutter (
      flutter.editRuntime (r: r // { jdk = r.jdk.override { version = "stage-only"; }; })
    );
    flutterProviderMetadata =
      (flutter.editRuntime (r: r // { dart = stable; })).tvp.deps.dart.drvPath == stable.drvPath;
    llvmEnvironment =
      environment.CC == "${dart.specification.llvm}/bin/clang"
      && environment.LD == "${dart.specification.llvm}/bin/ld.lld"
      && environment.NIX_CFLAGS_COMPILE == ""
      && environment.NIX_LDFLAGS == ""
      && !lib.hasSuffix "/llvm-as" environment.AS;
    loader = dart.tvp.dynamicLinker == dart.specification.llvm.tvp.dynamicLinker;
    flutterSnapshotFinal =
      !(builtins.any (s: lib.hasInfix "--snapshot=" (s.run or "")) partition.first)
      && builtins.any (
        s: s.name == "flutter.generate-final-tool" && lib.hasInfix ''sdk="$out/libexec/flutter"'' s.run
      ) partition.second;
    controls =
      builtins.length (builtins.attrNames stable.tests) == 2
      && builtins.length (builtins.attrNames dart.tests) == 9
      && builtins.length (builtins.attrNames flutter.tests) == 4;
    sourceLocksEffective = changedArtifact dart (dart.edit (s: s // { sourceLocks = [ ]; }));
    llvmPrefixEffective = changedArtifact dart (
      dart.override {
        llvm = dart.specification.llvm.editSteps (
          steps.append [
            {
              name = "llvm.stage-contract";
              run = ": selected-llvm-edit";
            }
          ]
        );
      }
    );
    dartFinalRuntime = builtins.all (edited: stableArtifact dart edited) [
      (dart.editRuntime (r: r // { shell = "${stable}/bin/bash"; }))
      (dart.editRuntime (r: r // { certificates = stable; }))
      (dart.editRuntime (r: r // { libraries = r.libraries ++ [ stable ]; }))
    ];
    flutterFinalRuntime = builtins.all (edited: stableArtifact flutter edited) [
      (flutter.editRuntime (r: r // { shell = stable; }))
      (flutter.editRuntime (r: r // { certificates = stable; }))
      (flutter.editRuntime (r: r // { androidSdk = tvp.android.profiles.latest; }))
      (flutter.editRuntime (r: r // { libraries = r.libraries ++ [ stable ]; }))
    ];
    runtimeTestsFollow =
      (dart.editRuntime (r: r // { loader = "${dart.runtime.loader}.edited"; })).tests.runtime.drvPath
      != dart.tests.runtime.drvPath;
    finalExclusions =
      builtins.all
        (package: builtins.elem package.artifact (package.outputChecks.out.disallowedReferences or [ ]))
        [
          stable
          dart
          flutter
        ];
    archiveRejectsHTTP =
      rejects
        (tvp.lib.sources.fetchArchive (
          archiveArgs // { url = "http://unsupported.invalid/archive.tar.gz"; }
        )).drvPath;
    archiveRejectsLocalEscape =
      rejects
        (tvp.lib.sources.fetchArchive (
          archiveArgs // { url = "file://${./sdk-archives/rootless.tar.gz}/../../escape"; }
        )).drvPath;
    archiveRejectsName =
      rejects
        (tvp.lib.sources.fetchArchive (archiveArgs // { name = "../source"; })).drvPath;
    unsupportedDevtools = rejects (dart.edit (s: s // { buildDevtoolsFromSources = true; })).drvPath;
    unsupportedStamps = rejects (dart.edit (s: s // { useCipdToolchainStamps = true; })).drvPath;
  };
  candidate = import ../../bases/source-gnu { };
  spec = dart.specification;
  target = spec.llvm.specification.runtime.target;
  probe = tvp.builder {
    recipe =
      {
        base,
        bash,
        coreutils,
        llvm,
        helperPython,
        binutils,
        patchelf,
      }:
      final: {
        pname = "sdk-runtime-probe";
        version = "1";
        src = null;
        inherit
          base
          bash
          coreutils
          llvm
          helperPython
          binutils
          patchelf
          ;
        runtime = {
          loader = llvm.tvp.dynamicLinker;
          libraries = [
            target.libc
            target.gccRuntime
            target.cxxRuntime
          ];
          message = "first";
        };
        plan = [
          {
            name = "probe.compile";
            tools = [
              llvm
              coreutils
              patchelf
            ];
            run = ''
              mkdir -p "$out/bin"
              ${llvm}/bin/clang -x c - -o "$out/bin/probe" <<'C'
              #include <stdio.h>
              int main(void) { puts("42"); return 0; }
              C
              ${llvm}/bin/clang -shared -fPIC -x c - -o "$out/bin/libprobe.so" <<'C'
              int answer(void) { return 42; }
              C
              ${patchelf}/bin/patchelf --set-rpath '$ORIGIN' "$out/bin/probe"
              ${coreutils}/bin/sha256sum "$out/bin/libprobe.so" | ${coreutils}/bin/cut -d' ' -f1 > "$out/shared.sha256"
            '';
          }
          (steps.split "probe.finalize")
          (outputs.copyArtifacts { inherit coreutils; })
          (outputs.hostELF {
            python = helperPython;
            inherit binutils patchelf;
            paths = [ "bin" ];
            loader = final.runtime.loader;
            libraries = final.runtime.libraries;
            executablesOnly = true;
          })
          (outputs.interpreters {
            python = helperPython;
            inherit binutils patchelf;
            paths = [ "bin" ];
            loader = final.runtime.loader;
          })
          (outputs.rpaths {
            python = helperPython;
            inherit binutils patchelf;
            paths = [ "bin/probe" ];
            libraries = final.runtime.libraries;
          })
          {
            name = "probe.check";
            tools = [
              coreutils
              patchelf
            ];
            run = ''
              test "$("$out/bin/probe")" = 42
              test "$(${coreutils}/bin/sha256sum "$out/bin/libprobe.so" | ${coreutils}/bin/cut -d' ' -f1)" = "$(cat "$out/shared.sha256")"
              test "$(${patchelf}/bin/patchelf --print-interpreter "$out/bin/probe")" = ${lib.escapeShellArg final.runtime.loader}
              ${final.runtime.loader} --list "$out/bin/probe" > resolved
              ${coreutils}/bin/cat resolved
              printf '%s' ${lib.escapeShellArg final.runtime.message} > "$out/message"
            '';
          }
        ];
      };
    args = {
      inherit (spec)
        base
        bash
        coreutils
        llvm
        helperPython
        binutils
        patchelf
        ;
    };
    dependencyNames = [ ];
    metadata = { };
    selection.kind = "fixture";
    mkTests = _: { };
  };
  relocatedRuntime = tvp.builder {
    recipe =
      {
        base,
        bash,
        coreutils,
        libc,
      }:
      final: {
        pname = "sdk-copied-runtime-fixture";
        version = "1";
        src = null;
        inherit base bash coreutils;
        plan = [
          {
            name = "runtime.copy";
            tools = [ coreutils ];
            run = ''
              mkdir -p "$out/lib"
              cp -L ${libc}/lib/ld-linux-x86-64.so.2 "$out/lib/ld-linux-x86-64.so.2"
              cp -L ${libc}/lib/libc.so.6 "$out/lib/libc.so.6"
            '';
          }
          (steps.split "runtime.finalize")
          (outputs.copyArtifacts { inherit coreutils; })
        ];
      };
    args = {
      inherit (spec) base bash coreutils;
      libc = target.libc;
    };
    dependencyNames = [ ];
    metadata = { };
    selection.kind = "fixture";
    mkTests = _: { };
  };
  archiveArgs = {
    url = "file://${./sdk-archives/rootless.tar.gz}";
    sha256 = "sha256-t6ZoXoKzfxYTJDjjSWUGt+Q8zE9fgNnMN12f+97WG0A=";
    inherit (spec)
      bash
      curl
      tar
      gzip
      coreutils
      ;
    python = spec.helperPython;
    certificates = spec.ca-certificates;
  };
in
{
  inherit contractValues;
  contracts =
    assert
      probe.artifact.drvPath == (probe.editRuntime (r: r // { message = "second"; })).artifact.drvPath;
    assert lib.all (x: x) (builtins.attrValues contractValues);
    contractValues;
  runtime = probe;
  runtimeEdit = probe.editRuntime (
    r:
    r
    // {
      message = "second";
      loader = "${relocatedRuntime}/lib/ld-linux-x86-64.so.2";
      libraries = [ relocatedRuntime ];
    }
  );
  leaking = probe.editSteps (
    steps.append [
      {
        name = "probe.leak";
        run = ''printf '%s' "$TVP_ARTIFACT_ROOT" > "$out/leak"'';
      }
    ]
  );
  archive = tvp.lib.sources.fetchArchive archiveArgs;
  badHash = tvp.lib.sources.fetchArchive (archiveArgs // { sha256 = lib.fakeHash; });
}

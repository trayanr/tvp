{ pkgs, tvp }:
let
  inherit (pkgs) lib;
  inherit (tvp.builder) steps outputs;
  base = tvp.bases.default;
  p = tvp.variants.build-steps.mpfr_4_2_2;
  inherit (tvp.packages) bash coreutils;
  python = tvp.packages.python_3;
  binutils = tvp.packages.binutils_2;
  patchelf = tvp.packages.patchelf_0;
  rejects = x: !(builtins.tryEval (builtins.deepSeq x true)).success;
  command = name: {
    inherit name;
    run = ":";
  };
  tool = name: data: {
    inherit name;
    outPath = "/tool/${name}";
    buildEnvironment = _: data;
  };
  merge = tools: overrides: (base.environment { inherit tools overrides; }).env;
  runtimeEdit = p.editRuntime (r: r // { libraries = [ tvp.packages.gmp_6_2_1 ]; });
  logged = p.edit (
    s:
    s
    // {
      environment = s.environment // {
        tools = s.environment.tools ++ [ coreutils ];
      };
    }
  );
  contracts = {
    finalEnvironment = logged.drvPath != p.drvPath;
    runtimeBoundary =
      runtimeEdit.artifact.drvPath == p.artifact.drvPath && runtimeEdit.drvPath != p.drvPath;
    runtimeProjection = runtimeEdit.out.runtime.libraries == runtimeEdit.runtime.libraries;
    toolOverrideProvider =
      (tvp.packages.pkg-config.override { }) ? buildEnvironment
      && (tvp.packages.pkg-config.edit (spec: spec)).out ? buildEnvironment;
    allProjection =
      (builtins.head runtimeEdit.out.all).tests.version.drvPath == runtimeEdit.tests.version.drvPath
      && (builtins.head runtimeEdit.all).out.tvp.customization.customized;
    runtimeTests = runtimeEdit.tests.version.drvPath != p.tests.version.drvPath;
    functionOverride =
      let
        prior = (p.editRuntime (r: r // { libraries = r.libraries ++ [ coreutils ]; })).override {
          gmp = tvp.packages.gmp_6_2_1;
          doCheck = true;
        };
      in
      (prior.override (args: {
        gmp = args.gmp;
        doCheck = !args.doCheck;
      })).out.tests.version.drvPath == (prior.override {
        gmp = tvp.packages.gmp_6_2_1;
        doCheck = false;
      }).tests.version.drvPath;
    orderedReplay =
      ((p.editRuntime (r: r // { libraries = r.libraries ++ [ coreutils ]; })).override {
        gmp = tvp.packages.gmp_6_2_1;
      }).runtime.libraries == [
        tvp.packages.gmp_6_2_1
        coreutils
      ];
    renamedMarker =
      rejects
        (p.editSteps (
          plan:
          steps.delete "mpfr.finalize" (steps.replace "mpfr.finalize" (_: steps.split "local.finalize") plan)
        )).drvPath;
    splitShape =
      steps.split "local.split" == {
        kind = "split";
        name = "local.split";
      };
    splitEnabled = rejects (
      steps.partition [
        (command "local.a")
        ((steps.split "local.split") // { enabled = false; })
        (command "local.b")
      ]
    );
    splitRun = rejects (
      steps.partition [
        (command "local.a")
        ((steps.split "local.split") // { run = ":"; })
        (command "local.b")
      ]
    );
    multiple = rejects (
      steps.partition [
        (command "local.a")
        (steps.split "local.one")
        (command "local.b")
        (steps.split "local.two")
        (command "local.c")
      ]
    );
    emptyBefore = rejects (
      steps.partition [
        (
          (command "local.a")
          // {
            enabled = false;
            run = throw "disabled";
          }
        )
        (steps.split "local.split")
        (command "local.b")
      ]
    );
    emptyAfter = rejects (
      steps.partition [
        (command "local.a")
        (steps.split "local.split")
      ]
    );
    disabledLazy =
      builtins.isString
        (p.editSteps (
          steps.insertBefore "mpfr.finalize" [
            {
              name = "local.disabled";
              enabled = false;
              tools = throw "disabled inputs";
              run = throw "disabled body";
            }
          ]
        )).drvPath;
    scalarConflict = rejects (
      merge [
        (tool "one" { values.EXAMPLE = "one"; })
        (tool "two" { values.EXAMPLE = "two"; })
      ] { }
    );
    typeConflict = rejects (
      merge [
        (tool "one" { values.EXAMPLE = "one"; })
        (tool "two" { flags.EXAMPLE = [ "two" ]; })
      ] { }
    );
    separatorConflict = rejects (
      merge [
        (tool "one" {
          paths.EXAMPLE = {
            separator = ":";
            entries = [ "one" ];
          };
        })
        (tool "two" {
          paths.EXAMPLE = {
            separator = ";";
            entries = [ "two" ];
          };
        })
      ] { }
    );
    explicitOverride =
      (merge [
        (tool "one" { values.EXAMPLE = "one"; })
        (tool "two" { flags.EXAMPLE = [ "two" ]; })
      ] { values.EXAMPLE = "selected"; }).EXAMPLE == "selected";
    paths =
      (merge [
        (tool "one" {
          paths.EXAMPLE = {
            separator = ":";
            entries = [
              "a"
              "b"
            ];
          };
        })
        (tool "two" {
          paths.EXAMPLE = {
            separator = ":";
            entries = [
              "b"
              "a"
              "c"
            ];
          };
        })
      ] { }).EXAMPLE == "a:b:c";
    emptyPathRejected = rejects (
      merge [
        (tool "empty" {
          paths.EXAMPLE = {
            separator = ":";
            entries = [ "" ];
          };
        })
      ] { }
    );
    pathSeparatorRejected = rejects (
      merge [
        (tool "separator" {
          paths.EXAMPLE = {
            separator = ":";
            entries = [ "a:b" ];
          };
        })
      ] { }
    );
    repeatedFlags =
      (base.environment {
        overrides.flags.NIX_CFLAGS_COMPILE = [
          "-O1"
          "-O2"
          "-O1"
        ];
      }).env.NIX_CFLAGS_COMPILE == "-O1 -O2 -O1";
    whitespaceRejected =
      rejects
        (base.environment { overrides.flags.NIX_CFLAGS_COMPILE = [ "-DNAME=a b" ]; }).env;
    newlineRejected =
      rejects
        (base.environment { overrides.flags.NIX_CFLAGS_COMPILE = [ "a\nb" ]; }).env;
    emptyRejected = rejects (base.environment { overrides.flags.NIX_CFLAGS_COMPILE = [ "" ]; }).env;
    protected = rejects (merge [ (tool "bad" { values.TVP_ARTIFACT_ROOT = "bad"; }) ] { });
    publicRequirements = map toString p.development.libraries == [ (toString tvp.packages.gmp_6) ];
    disabledExport =
      (p.editSteps (
        steps.replace "output.development" (
          old:
          old
          // {
            enabled = false;
            libraries = throw "disabled public inputs";
          }
        )
      )).development.libraries == [ ];
    linkerCommaRejected = rejects (base.environment { overrides.flags.NIX_LDFLAGS = [ "a,b" ]; }).env;
    unsupportedEncoder =
      rejects
        (base.environment { overrides.flags.UNKNOWN_FLAGS = [ "argument" ]; }).env;
    metadataOnly =
      (p.edit (s: s // { buildEnvironment = _: { values.EXAMPLE = "export"; }; })).drvPath == p.drvPath;
    noRawAttrs = !(p ? overrideAttrs);
    noSetup = !lib.hasInfix "/setup" (lib.concatStrings p.artifact.buildStepRunner.childScripts);
  };
  # Only MPFR is a library input. Its enabled development helper supplies GMP.
  consumer = tvp.builder {
    recipe =
      {
        base,
        bash,
        coreutils,
        src,
        version,
        mpfr,
        pkgConfig,
      }:
      {
        pname = "owned-mpfr-consumer";
        inherit
          base
          bash
          coreutils
          src
          version
          ;
        plan = [
          (
            (base.environment {
              tools = [
                (
                  pkgConfig
                  // {
                    buildEnvironment =
                      args:
                      (pkgConfig.buildEnvironment args)
                      // {
                        flags.NIX_CFLAGS_COMPILE = [
                          "-DSELECTED=11"
                          "-USELECTED"
                          "-DSELECTED=22"
                        ];
                      };
                  }
                )
              ];
              libraries = [ mpfr ];
            })
            // {
              name = "consumer.build";
              run = ''
                cat > consumer.c <<'C'
                #include <mpfr.h>
                #include <stdio.h>
                _Static_assert(SELECTED == 22, "ordered flags");
                int main(void) { mpfr_t x; mpfr_init2(x, 128); mpfr_set_ui(x, 42, MPFR_RNDN);
                  int ok = mpfr_cmp_ui(x, 42) == 0; mpfr_clear(x); puts(mpfr_get_version()); return !ok; }
                C
                test "$($PKG_CONFIG --modversion mpfr)" = 4.2.2
                "$CC" consumer.c $($PKG_CONFIG --cflags --libs mpfr) -o consumer
                env -i ./consumer
                mkdir "$out"
                cp consumer "$out/consumer"
              '';
            }
          )
        ];
      };
    args = {
      inherit base bash coreutils;
      src = p.src;
      version = "1";
      mpfr = p;
      pkgConfig = tvp.packages.pkg-config;
    };
    dependencyNames = [
      "mpfr"
      "pkgConfig"
    ];
    metadata = { };
    selection.kind = "fixture";
    mkTests = _: { };
  };
  # Same SONAME, different behavior. Building against A then selecting B must
  # actually load B, with A removed from the installed lookup path.
  provider =
    value: directory:
    tvp.builder {
      recipe =
        {
          base,
          bash,
          coreutils,
          src,
          version,
        }:
        {
          pname = "owned-runtime-${toString value}";
          inherit
            base
            bash
            coreutils
            src
            version
            ;
          plan = [
            (
              (base.environment { })
              // {
                name = "provider.build";
                run = ''
                  mkdir -p "$out/${directory}" "$out/bin"
                  printf 'int selected(void) { return %s; }\n' ${toString value} > selected.c
                  "$CC" -shared -Wl,-soname,libselected.so.1 selected.c -o "$out/${directory}/libselected.so.1"
                  ln -s libselected.so.1 "$out/${directory}/libselected.so"
                  printf '#!${bash}/bin/bash\nprintf selected-tool\n' > "$out/bin/make"
                  chmod +x "$out/bin/make"
                '';
              }
            )
          ];
        };
      args = {
        inherit base bash coreutils;
        src = p.src;
        version = "1";
      };
      dependencyNames = [ ];
      metadata = { };
      selection.kind = "fixture";
      mkTests = _: { };
    };
  a = provider 11 "lib";
  b =
    let
      package = provider 22 "lib64";
    in
    package // { development.libraryDirectories = [ "${package}/lib64" ]; };
  selfLinked = tvp.builder {
    recipe =
      {
        base,
        bash,
        coreutils,
        src,
        version,
      }:
      {
        pname = "owned-self-consumer";
        inherit
          base
          bash
          coreutils
          src
          version
          ;
        plan = [
          (
            (base.environment { tools = [ a ]; })
            // {
              name = "self.build";
              run = ''
                test "$(make)" = selected-tool
                mkdir -p "$out/lib" "$out/bin"
                printf 'int self(void) { return 42; }\n' > self.c
                "$CC" -fPIC -c self.c -o "$out/lib/self.o"
                "$CC" -shared -Wl,-soname,libself.so self.c -o "$out/lib/libself.so"
                printf 'extern int self(void); int main(void) { return self() != 42; }\n' > main.c
                "$CC" main.c -L"$out/lib" -Wl,-rpath,"$out/lib" -lself -o "$out/bin/app"
              '';
            }
          )
          (steps.split "self.finalize")
          (outputs.copyArtifacts { inherit coreutils; })
          (outputs.rpaths {
            inherit
              python
              binutils
              patchelf
              base
              ;
            paths = [
              "bin"
              "lib"
            ];
            elfKinds = [ "runtime" ];
            libraries = [ ];
          })
        ];
      };
    args = {
      inherit base bash coreutils;
      src = p.src;
      version = "1";
    };
    dependencyNames = [ ];
    metadata = { };
    selection.kind = "fixture";
    mkTests = _: { };
  };
  linked = tvp.builder {
    recipe =
      {
        base,
        bash,
        coreutils,
        src,
        version,
      }:
      final: {
        pname = "owned-runtime-consumer";
        inherit
          base
          bash
          coreutils
          src
          version
          ;
        runtime.libraries = [ a ];
        plan = [
          (
            (base.environment { libraries = [ a ]; })
            // {
              name = "consumer.build";
              run = ''
                mkdir -p "$out/bin"
                printf '#include <stdio.h>\nextern int selected(void); int main(void) { printf("%%d\\n", selected()); }\n' > main.c
                "$CC" main.c -lselected -o "$out/bin/selected"
              '';
            }
          )
          (steps.split "consumer.finalize")
          (outputs.copyArtifacts { inherit coreutils; })
          (outputs.rpaths {
            inherit
              python
              binutils
              patchelf
              base
              ;
            paths = [ "bin" ];
            libraries = final.runtime.libraries;
          })
        ];
      };
    args = {
      inherit base bash coreutils;
      src = p.src;
      version = "1";
    };
    dependencyNames = [ ];
    metadata = { };
    selection.kind = "fixture";
    mkTests = _: { };
  };
  changed = linked.editRuntime (_: {
    libraries = [
      b
      tvp.packages.zlib
    ];
  });
  failed = builtins.filter (n: !contracts.${n}) (builtins.attrNames contracts);
in
assert failed == [ ] || throw "Owned builder contracts: ${lib.concatStringsSep ", " failed}";
assert linked.artifact.drvPath == changed.artifact.drvPath;
(base.stdenv.mkDerivation {
  name = "tvp-owned-builder-contracts";
  buildCommand = ''
    test -x ${consumer}/consumer
    test "$(env -i ${linked}/bin/selected)" = 11
    test "$(env -i ${changed}/bin/selected)" = 22
    env -i ${selfLinked}/bin/app
    test -f ${selfLinked}/lib/self.o
    selfRpath=$(${patchelf}/bin/patchelf --print-rpath ${selfLinked}/bin/app)
    [[ "$selfRpath" == *"${selfLinked}/lib"* ]]
    [[ "$selfRpath" != *"${selfLinked.artifact}"* ]]
    rpath=$(${patchelf}/bin/patchelf --print-rpath ${changed}/bin/selected)
    [[ "$rpath" == *"${b}/lib64"* ]]
    [[ "$rpath" != *"${a}/lib"* ]]
    [[ "$rpath" == *"${tvp.packages.zlib}/lib"* ]]
    test "$(cat ${p}/nix-support/propagated-build-inputs)" = '${toString tvp.packages.gmp_6} '
    printf '%s\n' '${builtins.toJSON contracts}' > "$out"
  '';
})
// {
  passthru = {
    inherit
      contracts
      consumer
      linked
      changed
      runtimeEdit
      selfLinked
      ;
  };
}

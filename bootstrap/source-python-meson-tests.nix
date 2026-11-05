{
  bootstrap ? import ./. { },
}:
let
  f = import ./source-python-meson.nix { inherit bootstrap; };
  b = bootstrap;
  inherit (f.composition)
    lib
    base
    bash
    coreutils
    builder
    cc
    ;
  helpers = (import ../lib/native-steps.nix { inherit lib; }).meson;
  make =
    recipe:
    builder {
      inherit recipe;
      args = { };
      dependencyNames = [ ];
      metadata = { };
      selection.kind = "source-python-meson-proof";
      mkTests = _: { };
    };
  command =
    final: name: run:
    (final.base.environment final.environment) // { inherit name run; };
  binutils = b.gnu-binutils;
  patchelf = (import ./output-tool-prerequisites.nix { inherit bootstrap; }).patchelf;
  alternate = (import ./source-cmake-prerequisite-tests.nix { inherit bootstrap; }).alternate;
  sourceProbe =
    name: package:
    ((package.override { src = "${alternate}/source.tar.gz"; }).edit (
      s:
      s
      // {
        pname = "source-${name}-override";
        outputs = [ "out" ];
      }
    )).editSteps
      (plan: [
        (
          (builtins.head plan)
          // {
            tools = (builtins.head plan).tools ++ [ b.gzip ];
            run = builtins.replaceStrings [ "-xJf" ] [ "-xzf" ] (builtins.head plan).run;
          }
        )
        {
          name = "override.verify";
          run = ''test "$(cat source/marker)" = 'alternate source'; mkdir -p "$out"; cp source/marker "$out/"'';
        }
      ]);
  sourceOverridePython = sourceProbe "python" f.python;
  sourceOverrideMeson = sourceProbe "meson" f.meson;
  rebound = import ./source-base.nix {
    inherit bootstrap;
    compiler = cc // {
      outPath = "${cc}-constructor-test";
    };
  };
  configure =
    p:
    builtins.head (
      builtins.filter (s: s.name == "python.configure" || s.name == "meson.build") p.buildSteps
    );
  contracts = {
    pythonOverride = (f.python.override { }).drvPath == f.python.drvPath;
    mesonOverride = (f.meson.override { }).drvPath == f.meson.drvPath;
    pythonSteps = (f.python.editSteps (s: s)).drvPath == f.python.drvPath;
    mesonSteps = (f.meson.editSteps (s: s)).drvPath == f.meson.drvPath;
    pythonRuntime =
      (f.python.editRuntime (r: r // { libraries = r.libraries ++ [ f.prerequisites.zstd ]; })).drvPath
      != f.python.drvPath;
    pythonBase =
      (configure (f.python.edit (s: s // { base = rebound.base; }))).env.CC
      == "${cc}-constructor-test/bin/cc";
    conflictingProviderRejected =
      !(builtins.tryEval (
        builtins.deepSeq (base.environment {
          tools = [
            f.meson
            tracedPc
          ];
          libraries = [ ];
        }).env true
      )).success;
    reboundProvider =
      (base.environment {
        tools = [
          selectedMeson
          tracedPc
        ];
        libraries = [ ];
      }).env.PKG_CONFIG == "${tracedPc}/bin/pkg-config";
    mesonPythonOverride =
      let
        changed = f.meson.override {
          python = f.python // {
            outPath = "${f.python}-constructor-test";
          };
        };
        run = name: (builtins.head (builtins.filter (s: s.name == name) changed.buildSteps)).run;
        selected = "${f.python}-constructor-test/bin/python3";
      in
      lib.hasInfix ("--interpreter " + selected) (run "meson.build")
      && lib.hasInfix selected (run "meson.install");
    mesonEnvironment =
      (configure (
        f.meson.edit (
          s:
          s
          // {
            environment = s.environment // {
              overrides.values.OWNED_CALLBACK = "visible";
            };
          }
        )
      )).env.OWNED_CALLBACK == "visible";
    mesonBase =
      (configure (f.meson.edit (s: s // { base = rebound.base; }))).env.CC
      == "${cc}-constructor-test/bin/cc";
    pythonEnvironment =
      (configure (
        f.python.edit (
          s:
          s
          // {
            environment = s.environment // {
              overrides.values.OWNED_CALLBACK = "visible";
            };
          }
        )
      )).env.OWNED_CALLBACK == "visible";
    discovery =
      let
        e =
          (base.environment {
            tools = [ f.meson ];
            libraries = [ f.prerequisites.zlib ];
          }).env;
      in
      e.PKG_CONFIG == "${f.tools.pkgConfig}/bin/pkg-config"
      &&
        e.PKG_CONFIG_LIBDIR
        == "${f.prerequisites.zlib}/lib/pkgconfig:${f.prerequisites.zlib}/share/pkgconfig"
      && e.CMAKE_PREFIX_PATH == "${f.prerequisites.zlib}:${cc.libc}";
  };
  python = make (
    { }:
    final: {
      pname = "source-python-consumer";
      version = "1";
      src = null;
      inherit base bash coreutils;
      outputs = [
        "out"
        "evidence"
      ];
      environment = {
        tools = [
          f.python
          f.pythonOpenssl
        ];
        libraries = [ f.python ] ++ f.python.runtime.libraries;
      };
      plan = [
        (command final "python.check" ''
          mkdir -p "$out" "$evidence"
          ${f.python}/bin/python3 -B ${./source-python-checks.py} "$out" "$evidence" ${
            lib.escapeShellArg (
              builtins.toJSON {
                python = toString f.python;
                shell = "${bash}/bin/bash";
                openssl = "${f.pythonOpenssl}/bin/openssl";
                source = f.sources.python;
                disabled = f.python.passthru.disabledModules;
                archives = ../pkgs/runtimes/python-build/tests/fixtures/archives.py;
                embed = ../pkgs/runtimes/python-build/tests/fixtures/embed.c;
              }
            )
          }
        '')
      ];
    }
  );
  pythonCompatibility = make (
    { }:
    final: {
      pname = "source-python-compatibility";
      version = "1";
      src = null;
      inherit base bash coreutils;
      outputs = [
        "out"
        "evidence"
      ];
      environment = {
        tools = [ f.python ];
        libraries = [ ];
      };
      plan = [
        (command final "python.compatibility" ''
          mkdir -p "$out" "$evidence"
          ${f.python}/bin/python3 -B ${./source-python-compat-checks.py} "$out" "$evidence" ${
            lib.escapeShellArg (
              builtins.toJSON {
                python = toString f.python;
                openssl = "${f.pythonOpenssl}/bin/openssl";
                source = f.sources.python;
              }
            )
          }
        '')
      ];
    }
  );
  # Invoke real selected override wrappers, and rebind Meson's provider via the
  # existing recipe .override. A conflicting unrebound provider still fails.
  traced = make (
    { }:
    {
      pname = "source-meson-traced-tools";
      version = "1";
      src = null;
      inherit base bash coreutils;
      plan = [
        {
          name = "tools.install";
          run = ''
            mkdir -p "$out/bin"
            for name in ninja cmake pkg-config; do
              case "$name" in
                ninja) target=${f.tools.ninja}/bin/ninja;;
                cmake) target=${f.prior.cmake}/bin/cmake;;
                pkg-config) target=${f.tools.pkgConfig}/bin/pkg-config;;
              esac
              printf '#!%s\nprintf "%%s\\n" "%s $*" >> "$TOOL_TRACE"\nexec %s "$@"\n' ${bash}/bin/bash "$name" "$target" > "$out/bin/$name"
              chmod +x "$out/bin/$name"
            done
          '';
        }
      ];
    }
  );
  tracedPc = traced // {
    buildEnvironment = import ../lib/pkg-config-environment.nix;
  };
  selectedMeson = f.meson.override {
    ninja = traced;
    cmake = traced // {
      buildEnvironment = f.prior.cmake.buildEnvironment;
    };
    pkgConfig = tracedPc;
  };
  meson = make (
    { }:
    final: {
      pname = "source-meson-consumer";
      version = "1";
      src = null;
      inherit base bash coreutils;
      outputs = [
        "out"
        "evidence"
      ];
      environment = {
        tools = [
          f.meson
          f.tools.ninja
          f.python
          b.gnutar-latest
          f.prerequisites.xz
        ];
        libraries = [ f.prerequisites.zlib ];
      };
      runtime.libraries = final.environment.libraries;
      plan = [
        (command final "meson.check" ''
          mkdir -p "$out" "$evidence"
          ${f.python}/bin/python3 -B ${./source-meson-checks.py} "$out" "$evidence" ${
            lib.escapeShellArg (
              builtins.toJSON {
                meson = "${f.meson}/bin/meson";
                python = "${f.python}/bin/python3";
                zipapp = "${f.meson}/libexec/meson.pyz";
                source = f.sources.meson;
                shell = "${bash}/bin/bash";
                cmake = "${f.prior.cmake}/bin/cmake";
                ninja = "${f.tools.ninja}/bin/ninja";
                pkgConfig = "${f.tools.pkgConfig}/bin/pkg-config";
                traced = toString traced;
                selectedMeson = "${selectedMeson}/bin/meson";
                zlib = toString f.prerequisites.zlib;
                fixture = ../pkgs/build-tools/meson/tests/fixtures;
                inherit contracts;
              }
            )
          }
        '')
      ];
    }
  );
  # Existing native steps helper on an installed owned consumer (both methods).
  helperConsumer = make (
    { }:
    final: {
      pname = "source-meson-helper-consumer";
      version = "1";
      src = null;
      inherit base bash coreutils;
      environment = {
        tools = [ selectedMeson ];
        libraries = [ f.prerequisites.zlib ];
      };
      plan = builder.steps.sequence [
        {
          name = "fixture.prepare";
          run = ''
            mkdir source
            cp ${../pkgs/build-tools/meson/tests/fixtures/meson.build} source/meson.build
            cp ${../pkgs/build-tools/meson/tests/fixtures/answer.c} source/answer.c
            cp ${../pkgs/build-tools/meson/tests/fixtures/main.cc} source/main.cc
            chmod u+w source/meson.build
            ${b.build-python}/bin/python3 -B - <<'PYTHON'
            from pathlib import Path
            p = Path('source/meson.build')
            p.write_text(p.read_text().replace('install_rpath:', "build_rpath: join_paths(get_option('prefix'), get_option('libdir')), install_rpath:"))
            PYTHON
          '';
        }
        (map
          (
            s:
            let
              e = final.base.environment final.environment;
            in
            e
            // s
            // {
              tools = lib.unique (e.tools ++ s.tools);
              env = e.env // s.env;
            }
          )
          (helpers {
            name = "meson";
            meson = selectedMeson;
            ninja = traced;
            pkg-config = tracedPc;
            libraries = [ f.prerequisites.zlib ];
            env = {
              TOOL_TRACE = "tool-trace.log";
            };
          })
        )
      ];
    }
  );
in
assert builtins.all (x: x) (builtins.attrValues contracts);
{
  inherit
    pythonCompatibility
    f
    python
    meson
    helperConsumer
    traced
    selectedMeson
    sourceOverridePython
    sourceOverrideMeson
    contracts
    ;
}

# Installed compressed zipapp, source and installed units, traced tools and XZ wrap.
{
  pkgs,
  tvp,
  package,
  zlib,
}:
let
  inherit (pkgs) lib;
  d = package.tvp.deps;
  make =
    recipe: args:
    tvp.builder {
      inherit recipe args;
      dependencyNames = builtins.attrNames args;
      metadata.kind = "native-frontend-profile";
      selection.kind = "test-support";
      mkTests = _: { };
    };
  traced =
    make
      (
        {
          base,
          bash,
          coreutils,
          ninja,
          cmake,
          pkgConfig,
        }:
        {
          pname = "meson-selected-tools";
          version = "1";
          src = null;
          inherit base bash coreutils;
          plan = [
            {
              name = "trace.install";
              run = ''
                mkdir -p "$out/bin"
                for name in ninja cmake pkg-config; do
                  case "$name" in
                    ninja) target=${ninja}/bin/ninja;;
                    cmake) target=${cmake}/bin/cmake;;
                    pkg-config) target=${pkgConfig}/bin/pkg-config;;
                  esac
                  printf '#!%s\nprintf "%%s\\n" "%s $*" >> "$TOOL_TRACE"\nexec %s "$@"\n' ${bash}/bin/bash "$name" "$target" > "$out/bin/$name"
                  chmod +x "$out/bin/$name"
                done
              '';
            }
          ];
        }
      )
      {
        inherit (package.specification) base bash coreutils;
        inherit (package.runtime) ninja cmake;
        pkgConfig = package.runtime.pkg-config;
      };
  pc = traced // {
    buildEnvironment = import ../../../../lib/pkg-config-environment.nix;
  };
  cm = traced // {
    buildEnvironment = package.runtime.cmake.buildEnvironment;
  };
  selected = package.override {
    ninja = traced;
    cmake = cm;
    pkg-config = pc;
  };
  rejects = x: !(builtins.tryEval (builtins.deepSeq x true)).success;
  contracts = {
    conflict =
      rejects
        (package.specification.base.environment {
          tools = [
            package
            pc
          ];
        }).env;
    rebind =
      (package.specification.base.environment {
        tools = [
          selected
          pc
        ];
      }).env.PKG_CONFIG == "${pc}/bin/pkg-config";
  };
in
assert builtins.all (x: x) (builtins.attrValues contracts);
make
  (
    {
      base,
      bash,
      coreutils,
      meson,
      selected,
      traced,
      zlib,
      python,
      tar,
      xz,
      cmake,
      ninja,
      pkgConfig,
    }:
    final: {
      pname = "meson-native-profile";
      version = package.version;
      src = null;
      inherit base bash coreutils;
      outputs = [
        "out"
        "evidence"
      ];
      environment = {
        tools = [
          meson
          python
          tar
          xz
          ninja
        ];
        libraries = [ zlib ];
      };
      plan = [
        (
          (final.base.environment final.environment)
          // {
            name = "profile.consumers";
            run = ''
              mkdir -p "$out" "$evidence"
              ${python}/bin/python3 -B ${../../../../bootstrap/source-meson-checks.py} "$out" "$evidence" ${
                lib.escapeShellArg (
                  builtins.toJSON {
                    meson = "${meson}/bin/meson";
                    python = "${python}/bin/python3";
                    zipapp = "${meson}/libexec/meson.pyz";
                    source = meson.src;
                    shell = "${meson.runtime.shell}/bin/bash";
                    cmake = "${cmake}/bin/cmake";
                    ninja = "${ninja}/bin/ninja";
                    pkgConfig = "${pkgConfig}/bin/pkg-config";
                    traced = toString traced;
                    selectedMeson = "${selected}/bin/meson";
                    zlib = toString zlib;
                    fixture = ./fixtures;
                    inherit contracts;
                  }
                )
              }
            '';
          }
        )
      ];
    }
  )
  {
    inherit (package.specification) base bash coreutils;
    meson = package;
    inherit selected traced zlib;
    inherit (package.runtime) python cmake ninja;
    pkgConfig = package.runtime.pkg-config;
    tar = d.gnutar;
    xz = d.python.tvp.deps.xz;
  }

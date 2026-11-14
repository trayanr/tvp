# Bounded upstream script scopes and installed native/TLS/archive consumers.
{
  package,
  lib,
  context,
}:
let
  builder = import ../../../../lib/builder.nix { inherit lib; };

  d = package.tvp.deps;
  jsonC = package.tvp.declaredTestDependencies.jsonC;
  ninja = package.tvp.declaredTestDependencies.ninja;
in
builder {
  recipe =
    {
      base,
      bash,
      coreutils,
      cmake,
      ninja,
      jsonC,
      python,
      make,
      pkgConfig,
      openssl,
      zlib,
      tar,
      gzip,
      findutils,
      sed,
      grep,
      binutils,
      patchelf,
    }:
    final: {
      pname = "cmake-native-profile";
      version = package.version;
      src = null;
      inherit base bash coreutils;
      outputs = [
        "out"
        "evidence"
      ];
      environment = {
        tools = [
          cmake
          ninja
          python
          make
          pkgConfig
          openssl
          tar
          gzip
          findutils
          sed
          grep
        ];
        libraries = [
          zlib
          jsonC
        ];
      };
      plan = [
        (
          (final.base.environment final.environment)
          // {
            name = "profile.consumers";
            run = ''
              mkdir -p "$out" "$evidence"
              ${python}/bin/python3 -B ${../../../../bootstrap/source-cmake-checks.py} "$out" "$evidence" ${
                lib.escapeShellArg (
                  builtins.toJSON {
                    cmake = "${cmake}/bin/cmake";
                    ctest = "${cmake}/bin/ctest";
                    cpack = "${cmake}/bin/cpack";
                    make = "${make}/bin/make";
                    ninja = "${ninja}/bin/ninja";
                    openssl = "${openssl}/bin/openssl";
                    pkgConfig = "${pkgConfig}/bin/pkg-config";
                    jsonC = toString jsonC;
                    zlib = toString zlib;
                    # Native CMake preserves its fixed-width compiled shell slot.
                    shell =
                      let
                        shell = "${cmake.runtime.shell}/bin/bash";
                      in
                      assert builtins.stringLength shell <= 256;
                      lib.concatStrings (lib.replicate (256 - builtins.stringLength shell) "/") + shell;
                    source = cmake.src;
                    fixture = {
                      "CMakeLists.txt" = ./fixtures/CMakeLists.txt;
                      "answer.c" = ./fixtures/answer.c;
                      "main.cc" = ./fixtures/main.cc;
                    };
                    api = ../../../libraries/json-c/tests/fixtures/api.c;
                    contracts = {
                      ordinary = cmake.tvp.base == "source-gnu-candidate";
                    };
                  }
                )
              }
            '';
          }
        )
        (builder.outputs.rpaths {
          inherit python binutils patchelf;
          base = final.base;
          paths = [
            "make/bin"
            "make/lib"
            "ninja/bin"
            "ninja/lib"
            "json/bin"
          ];
          libraries = final.environment.libraries;
        })
        {
          name = "profile.installed";
          tools = [ python ];
          run = ''${python}/bin/python3 -B ${../../../../bootstrap/source-cmake-checks.py} installed "$out" "$evidence"'';
        }
      ];
    };
  args = {
    inherit (package.specification) base bash coreutils;
    cmake = package;
    inherit ninja jsonC;
    python = package.specification.helperPython;
    make = package.specification.gnumake;
    pkgConfig = package.specification.pkg-config;
    inherit (d) openssl zlib binutils;
    inherit (package.specification)
      findutils
      sed
      grep
      gzip
      patchelf
      ;
    tar = package.specification.gnutar;
  };
  dependencyNames = [
    "cmake"
    "ninja"
    "jsonC"
    "python"
    "make"
    "pkgConfig"
    "openssl"
    "zlib"
    "tar"
    "gzip"
    "findutils"
    "sed"
    "grep"
    "binutils"
    "patchelf"
  ];
  metadata.kind = "native-frontend-profile";
  selection.kind = "test-support";
  mkTests = _: { };
}

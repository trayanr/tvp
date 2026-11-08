# Bounded upstream script scopes and installed native/TLS/archive consumers.
{
  pkgs,
  tvp,
  package,
  ninja,
}:
let
  inherit (pkgs) lib;
  d = package.tvp.deps;
  jsonC = tvp.packages.json-c;
in
tvp.builder {
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
                    shell = "${cmake.runtime.shell}/bin/bash";
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
        (tvp.builder.outputs.rpaths {
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
    python = d.helperPython;
    make = d.gnumake;
    pkgConfig = d.pkg-config;
    inherit (d)
      openssl
      zlib
      findutils
      sed
      grep
      gzip
      binutils
      patchelf
      ;
    tar = d.gnutar;
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

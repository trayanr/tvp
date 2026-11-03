# Shared/static, app, pointer, patch and CTest options retain upstream defaults.
{
  tvp,
  lib,
  base,
  src,
  version,
  patches,
  bash,
  coreutils,
  cmake,
  gnumake,
  gnutar,
  gzip,
  patch,
  python,
  binutils,
  patchelf,
  doCheck ? true,
}:
let
  inherit (tvp.builder) steps outputs;
  elfPaths = [ "lib/libjson-c.so.5.5.0" ];
in
final:
let
  environment = final.base.environment final.environment;
in
{
  pname = "json-c";
  inherit
    base
    src
    version
    bash
    coreutils
    ;
  environment = {
    tools = [
      cmake
      gnumake
    ];
    libraries = [ ];
  };
  cmakeOptions = {
    sourceDirectory = "source";
    buildDirectory = "build";
    cmakeFlags = [ ];
    checkFlags = [ ];
  };
  runtime = {
    libraries = [ ];
    dlopenDirectories = [ ];
  };
  plan = steps.sequence [
    (steps.unpack {
      inherit src gzip;
      tar = gnutar;
      compression = "gzip";
    })
    {
      name = "source.patch";
      cwd = "source";
      tools = [ patch ];
      run = lib.concatMapStringsSep "\n" (
        p: "${patch}/bin/patch -p1 < ${lib.escapeShellArg "${p}"}"
      ) patches;
    }
    (
      (steps.shebangs {
        name = "source.prepare-tests";
        inherit python;
        paths = [ "tests" ];
        names = [
          "sh"
          "bash"
        ];
        interpreter = "${bash}/bin/bash";
      })
      // {
        enabled = doCheck;
      }
    )
    (steps.cmake (
      final.cmakeOptions
      // {
        name = "json-c";
        inherit cmake doCheck;
        make = gnumake;
        inherit (environment) tools libraries env;
      }
    ))
    {
      name = "json-c.epoch";
      run = ''
        mkdir -p "$out/nix-support"
        cp source-date-epoch "$out/nix-support/source-date-epoch"
      '';
    }
    (steps.split "json-c.finalize")
    (outputs.copyArtifacts { inherit coreutils; })
    (outputs.relocateText {
      inherit python;
      paths = [ "lib/pkgconfig/json-c.pc" ];
    })
    (outputs.strip {
      inherit python binutils;
      paths = elfPaths;
    })
    (outputs.stripArchives {
      inherit python binutils;
      paths = [ "lib/libjson-c.a" ];
    })
    (outputs.rpaths {
      inherit python binutils patchelf;
      base = final.base;
      paths = elfPaths;
      libraries = final.runtime.libraries;
      inherit (final.runtime) dlopenDirectories;
    })
    (outputs.development {
      inherit python;
      libraries = [ ];
    })
    (outputs.checkSymlinks {
      inherit python;
      paths = [
        "lib/libjson-c.so"
        "lib/libjson-c.so.5"
      ];
    })
    (outputs.checkPaths {
      inherit python binutils patchelf;
      paths = elfPaths;
    })
  ];
  tvp.features = {
    inherit doCheck;
    shared = true;
    static = true;
    jsonPointer = true;
    jsonPatch = true;
    installedCLI = false;
  };
  meta = {
    description = "JSON parser, serializer and reference-counted object library in C";
    homepage = "https://github.com/json-c/json-c";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
  };
}

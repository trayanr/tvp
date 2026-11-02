# Package-local native experiment; canonical build-0.19.nix is independent.
{
  lib,
  stdenv,
  fetchurl,
  cmake,
  bash,
  coreutils,
  gnumake,
  gnutar,
  gzip,
  patch,
  base,
  version,
  sha256,
  tagDate,
  patches,
  mkTests,
  doCheck ? true,
  editSteps ? (plan: plan),
}@args:
let
  steps = import ../../../lib/build-steps.nix;
  src = fetchurl {
    url = "https://github.com/json-c/json-c/releases/download/json-c-${version}-${tagDate}/json-c-${version}.tar.gz";
    inherit sha256;
  };
  plan = editSteps (
    steps.namespace "source" [
      {
        name = "unpack";
        tools = [
          gnutar
          gzip
        ];
        run = ''
          mkdir source
          tar -xzf ${src} --strip-components=1 -C source
          chmod -R u+w source
          updateSourceDateEpoch source
          printf '%s\n' "$SOURCE_DATE_EPOCH" > source-date-epoch
        '';
      }
      {
        name = "patch";
        cwd = "source";
        tools = [ patch ];
        run = lib.concatMapStringsSep "\n" (p: "patch -p1 < ${lib.escapeShellArg "${p}"}") patches;
      }
      {
        name = "prepare-tests";
        cwd = "source";
        # Vendored setup helpers expect optional unset variables (no nounset).
        run = ''
          set +u
          patchShebangs tests
          set -u
        '';
      }
    ]
    ++ import ./steps-cmake.nix { inherit lib; } {
      name = "json-c";
      inherit cmake doCheck;
      make = gnumake;
    }
    ++ steps.namespace "output" [
      {
        name = "fixup";
        run = ''
          # Explicit single-output bridge to the selected base's retained helpers.
          # They expect optional unset variables; no genericBuild phase dispatch.
          outputs=out
          dontStrip= dontShrinkRpaths= noAuditTmpdir=
          stripDebugList='lib lib32 lib64 libexec bin sbin'
          stripDebugFlags='-S -p'
          set +u
          fixupPhase
          set -u
        '';
      }
    ]
  );
  runner =
    import ../../../lib/build-step-runner.nix
      {
        inherit
          lib
          base
          bash
          coreutils
          ;
      }
      {
        plan = map (
          step:
          step
          // {
            run =
              ''
                # Match this selected compiler's default hardening, in every fresh shell.
                export NIX_HARDENING_ENABLE=${lib.escapeShellArg (lib.concatStringsSep " " stdenv.cc.defaultHardeningFlags)}
              ''
              + (
                if step.name == "source.unpack" then
                  ""
                else
                  ''
                    export SOURCE_DATE_EPOCH=$(cat "$TVP_SOURCE_ROOT/source-date-epoch")
                  ''
              )
              + step.run;
          }
        ) (steps.active plan);
      };
in
stdenv.mkDerivation (finalAttrs: {
  pname = "json-c";
  inherit version src patches;
  outputs = [ "out" ];
  buildCommand = ''
    mkdir workspace
    ${bash}/bin/bash ${runner.script} "$PWD/workspace"
  '';
  meta = {
    description = "JSON parser, serializer and reference-counted object library in C";
    homepage = "https://github.com/json-c/json-c";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
  };
  passthru = {
    tvp.deps = {
      inherit
        cmake
        bash
        coreutils
        gnumake
        gnutar
        gzip
        patch
        ;
    };
    tvp.cc = stdenv.cc;
    tests = mkTests finalAttrs.finalPackage;
    # Private inspection/composition points, excluded from catalogue metadata.
    buildSteps = plan;
    withBuildSteps = changes: import ./build-steps-0.19.nix (args // changes);
    buildStepRunner = runner;
  };
})

# Opt-in CMake and its existing owned JSON-C consumer. No catalogue changes.
{
  bootstrap ? import ./. { },
}:
let
  b = bootstrap;
  prerequisites = import ./source-cmake-prerequisites.nix { inherit bootstrap; };
  tools = import ./source-build-tools.nix { inherit bootstrap; };
  composition = prerequisites.composition;
  inherit (composition)
    lib
    base
    bash
    coreutils
    builder
    ;
  sources = builtins.mapAttrs (_: import <nix/fetchurl.nix>) (
    builtins.fromJSON (builtins.readFile ./source-cmake-sources.json)
  );
  make =
    recipe: args:
    builder {
      inherit recipe args;
      dependencyNames = builtins.attrNames args;
      metadata = { };
      selection.kind = "source-cmake";
      mkTests = _: { };
    };
  common = {
    tvp = {
      inherit builder;
    };
    inherit
      lib
      base
      bash
      coreutils
      ;
    python = b.build-python;
    gnumake = b.gnu-tool-floor.gnu-make;
    gnutar = b.gnutar-latest;
    gzip = b.gzip;
    patch = b.gnupatch;
    binutils = b.gnu-binutils;
    patchelf = (import ./output-tool-prerequisites.nix { inherit bootstrap; }).patchelf;
  };
  findutils = b.gnu-tool-floor.gnu-findutils;
  cmake = make (import ../pkgs/build-tools/cmake/owned/build-4.4.5.nix) (
    common
    // {
      inherit findutils;
      src = sources.cmake;
      version = "4.4.5";
      inherit (prerequisites)
        openssl
        zlib
        bzip2
        xz
        zstd
        ;
      inherit (tools) pkgConfig;
      sed = b.gnused;
      grep = b.build-grep;
      gawk = b.gawk;
      diffutils = b.diffutils;
    }
  );
  jsonC =
    (
      (make (import ../pkgs/libraries/json-c/build-0.19.nix) (
        common
        // {
          inherit cmake;
          src = sources.json-c;
          version = "0.19";
          patches = [ ../pkgs/libraries/json-c/patches/posix-test-byte.patch ];
        }
      )).edit
      (
        s:
        s
        // {
          environment = s.environment // {
            tools = s.environment.tools ++ [
              b.gnused
              b.build-grep
              b.diffutils
            ];
          };
        }
      )
    ).editSteps
      (
        plan:
        builder.steps.insertAfter "output.copy-artifacts"
          [
            {
              name = "json-c.remove-evidence";
              run = ''rm -rf "$out/.tvp-evidence"'';
            }
          ]
          (
            map
              (
                old:
                if
                  builtins.elem old.name [
                    "json-c.configure"
                    "json-c.build"
                    "json-c.check"
                    "json-c.install"
                  ]
                then
                  old
                  // {
                    run = ''
                      mkdir -p "$out/.tvp-evidence"
                      status=0
                      ${bash}/bin/bash -euc ${lib.escapeShellArg old.run} > "$out/.tvp-evidence/${old.name}.log" 2>&1 || status=$?
                      printf '%s\n' "$status" > "$out/.tvp-evidence/${old.name}.status"
                      if (( status )); then cat "$out/.tvp-evidence/${old.name}.log"; exit "$status"; fi
                    '';
                  }
                else
                  old
              )
              (
                builder.steps.replace "source.unpack" (
                  old: old // { tools = lib.unique (old.tools ++ [ findutils ]); }
                ) plan
              )
          )
      );
in
{
  inherit
    composition
    prerequisites
    tools
    sources
    cmake
    jsonC
    ;
}

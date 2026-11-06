# Explicit GCC diagram-test composition. Earlier construction tools retain their
# own measured runtime generations; new rendering code uses the native capability base.
{
  bootstrap ? import ./. { },
}:
let
  previous = import ./source-gcc-python-tests.nix { inherit bootstrap; };
  pythonMeson = import ./source-python-meson.nix { inherit bootstrap; };
  cmakeProfile = import ./source-cmake.nix { inherit bootstrap; };
  inherit (previous.composition)
    lib
    base
    bash
    coreutils
    builder
    ;
  tools = previous.tools // {
    cmake = cmakeProfile.cmake;
    ninja = pythonMeson.tools.ninja;
    meson = pythonMeson.meson;
    bison = bootstrap.build-bison;
    m4 = bootstrap.build-m4;
  };
  sources = builtins.mapAttrs (_: import <nix/fetchurl.nix>) (
    builtins.fromJSON (builtins.readFile ./source-gcc-graphviz-sources.json)
  );
  make =
    recipe: args:
    builder {
      inherit recipe args;
      dependencyNames = builtins.attrNames args;
      metadata = { };
      selection.kind = "source-gcc-graphviz";
      mkTests = _: { };
    };
  common = {
    inherit
      lib
      base
      bash
      coreutils
      ;
    tvp = {
      inherit builder;
    };
    inherit (tools)
      python
      binutils
      patchelf
      xz
      gzip
      findutils
      ;
    gnutar = tools.tar;
    buildTools = map (n: tools.${n}) [
      "make"
      "sed"
      "grep"
      "gawk"
      "diffutils"
    ];
  };
  packages = rec {
    gperf = make (import ../pkgs/build-tools/gperf/owned/build-3.3.nix) (
      common
      // {
        src = sources.gperf;
        version = "3.3";
        gnumake = tools.make;
        libstdcxx = previous.harness.native.profile.libstdcxx;
      }
    );
    flex = make (import ../pkgs/build-tools/flex/owned/build-2.6.4.nix) (
      common
      // {
        src = sources.flex;
        version = "2.6.4";
        gnumake = tools.make;
        inherit (tools) bison m4;
      }
    );
    png = make (import ../pkgs/libraries/libpng/build-1.6.43.nix) (
      common
      // {
        src = sources.png;
        version = "1.6.43";
        gnumake = tools.make;
        zlib = previous.harness.prerequisites.zlib;
      }
    );
    freetype = make (import ../pkgs/libraries/freetype/owned/build-2.15.0.nix) (
      common
      // {
        src = sources.freetype;
        version = "2.15.0";
        gnumake = tools.make;
        pkgConfig = tools.pkgConfig;
        zlib = previous.harness.prerequisites.zlib;
        bzip2 = pythonMeson.prerequisites.bzip2;
      }
    );
    expat = make (import ../pkgs/libraries/expat/owned/build-2.9.0.nix) (
      common
      // {
        src = sources.expat;
        version = "2.9.0";
        inherit (tools) cmake ninja;
      }
    );
    fontconfig =
      (
        (make (import ../pkgs/libraries/fontconfig/build-steps-2.18.3.nix) {
          inherit
            lib
            base
            bash
            coreutils
            ;
          tvp = {
            inherit builder;
          };
          src = sources.fontconfig;
          version = "2.18.3";
          gnutar = tools.tar;
          inherit (tools)
            xz
            python
            binutils
            patchelf
            meson
            ninja
            ;
          pkg-config = tools.pkgConfig;
          inherit freetype expat gperf;
        }).edit
        (
          s:
          s
          // {
            outputs = [
              "out"
              "evidence"
            ];
          }
        )
      ).editSteps
        (
          plan:
          map (
            s:
            s
            // {
              tools = (s.tools or [ ]) ++ [
                tools.findutils
                tools.sed
                tools.grep
                tools.diffutils
              ];
            }
            //
              lib.optionalAttrs
                (builtins.elem s.name [
                  "fontconfig.configure"
                  "fontconfig.build"
                  "fontconfig.check"
                  "fontconfig.install"
                ])
                {
                  run = ''
                    mkdir -p "$evidence"
                    export TVP_SOURCE_ROOT
                    status=0
                    ${bash}/bin/bash -euc ${lib.escapeShellArg s.run} > "$evidence/${s.name}.log" 2>&1 || status=$?
                    printf '%s\n' "$status" > "$evidence/${s.name}.status"
                    ${lib.optionalString (s.name == "fontconfig.check") ''cp -r meson-logs "$evidence/meson-logs"''}
                    if (( status )); then cat "$evidence/${s.name}.log"; exit "$status"; fi
                  '';
                }
          ) plan
        );
    ltdl = make (import ../pkgs/libraries/libltdl/build-2.4.7.nix) (
      common
      // {
        src = sources.ltdl;
        version = "2.4.7";
        gnumake = tools.make;
      }
    );
    gd = make (import ../pkgs/libraries/libgd/build-2.3.3.nix) (
      common
      // {
        src = sources.gd;
        version = "2.3.3";
        inherit (tools) cmake ninja pkgConfig;
        fontData = fonts;
        perl = tools.perl;
        inherit png freetype fontconfig;
        zlib = previous.harness.prerequisites.zlib;
      }
    );
    graphviz = make (import ../pkgs/tools/graphviz/build-12.1.0.nix) (
      common
      // {
        src = sources.graphviz;
        version = "12.1.0";
        inherit (tools)
          cmake
          ninja
          pkgConfig
          bison
          patch
          ;
        inherit
          flex
          gd
          freetype
          fontconfig
          expat
          ltdl
          ;
        zlib = previous.harness.prerequisites.zlib;
        patches = [ ../pkgs/tools/graphviz/patches/gd-feature-probes.patch ];
      }
    );
  };
  fonts = make (import ../pkgs/data/dejavu/ttf-2.37.nix) {
    inherit base bash coreutils;
    src = sources.fonts;
    python = tools.python;
  };
in
{
  inherit
    previous
    tools
    sources
    packages
    fonts
    ;
  composition = previous.composition;
}

# mpdecimal 4.0.1 complete installed/source-layout procedure with independent upstream checkpoint.
{
  tvp,
  lib,
  base,
  src,
  version,
  doCheck ? true,
  cStandard ? null,
  cFlags ? [ ],
  patches ? [ ],
}:
final:
let
  context = tvp.builder.forBase final.base;
  inherit (context) steps outputs tools;
  environment = final.base.environment final.environment;
  command =
    name:
    steps.command {
      environment = final.environment;
    } "mpdecimal.${name}";
  make = ''${tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${tools.bash}/bin/bash'';
  checkpoint = "nix-support/mpdecimal-build-tree";
  headerDirectory = "include";
in
{
  pname = "mpdecimal";
  artifactName = "${final.pname}-${final.version}";
  inherit
    base
    src
    version
    doCheck
    cStandard
    cFlags
    patches
    ;
  inherit (tools) bash coreutils;
  buildFeatures = {
    cStandard = final.cStandard;
    cFlags = final.cFlags;
    shared = true;
    static = false;
    cxx = true;
  };
  installedInterface = {
    cxx = true;
  };
  sourceLayout = {
    libtoolAnchors = { };
    selections = [
      "configure"
      "config.sub"
      "config.guess"
      "install-sh"
    ];
    shellFragments = { };
  };
  upstreamSourceLayout = {
    requireConfigure = false;
    allowBoundShell = true;
    libtoolAnchors = { };
    shellFragments = { };
    selections = [
      "tests"
      "tests++"
    ];
    documentedData = {
      "tests/gettests.bat" = {
        magic = "404543484f204f46";
        mode = 493;
        sha256 = "035a368e491a058662cd79736c69526af12362900544d2a8b241ae3d4b088945";
      };
    };
  };
  configureFlags = [
    (if final.buildFeatures.cxx then "--enable-cxx" else "--disable-cxx")
    (if final.buildFeatures.shared then "--enable-shared" else "--disable-shared")
    (if final.buildFeatures.static then "--enable-static" else "--disable-static")
  ];
  environment = {
    tools = [
      tools.pkg-config
      tools.gnumake
      tools.sed
      tools.grep
      tools.gawk
      tools.diffutils
      tools.findutils
    ];
    libraries = [ ];
  };
  runtime = {
    libraries = [ ];
    dlopenDirectories = [ ];
    shell = tools.bash;
    tools = [
      tools.coreutils
      tools.sed
      tools.grep
      tools.gawk
      tools.diffutils
      tools.findutils
    ];
  };
  productionPlan = steps.sequence [
    (steps.unpack {
      src = final.src;
      compression = "gzip";
    })
    (
      (command "prepare" "${tools.python}/bin/python3 -B ${../ffi-decimal-source.py} ${tools.bash}/bin/bash ${
        lib.escapeShellArg (
          builtins.toJSON (final.sourceLayout // { patches = map (p: "${p}") final.patches; })
        )
      } ")
      // {
        tools = environment.tools ++ [ tools.python ];
      }
    )
    (command "configure" ''
      export CONFIG_SHELL=${tools.bash}/bin/bash SHELL=${tools.bash}/bin/bash
      ${lib.optionalString (final.buildFeatures.cStandard != null || final.buildFeatures.cFlags != [ ])
        "export CFLAGS=${
          lib.escapeShellArg (
            lib.concatStringsSep " " (
              [ "-O2" ]
              ++ lib.optional (final.buildFeatures.cStandard != null) "-std=${final.buildFeatures.cStandard}"
              ++ final.buildFeatures.cFlags
            )
          )
        }"
      }
      ./configure --prefix="$out" --libdir="$out/lib" ${lib.escapeShellArgs final.configureFlags} 
    '')
    (command "build" make)
    (command "install" ''
      ${make} install
      mkdir -p "$out/nix-support"
      cp "$TVP_SOURCE_ROOT/source-date-epoch" "$out/nix-support/source-date-epoch"
    '')
    (
      (command "save-build-tree" ''${tools.python}/bin/python3 -B ${../../../lib/build-checkpoint.py} "$TVP_SOURCE_ROOT" "$out/${checkpoint}"'')
      // {
        tools = environment.tools ++ [ tools.python ];
      }
    )
  ];
  upstreamPlan = artifact: [
    (steps.restoreCheckpoint {
      name = "mpdecimal.restore-build-tree";
      checkpoint = "${artifact}/${checkpoint}";
    })
    {
      name = "mpdecimal.upstream-source";
      tools = [ tools.python ];
      env = final.upstreamCheck.env;
      run = ''
        cd "$(cat "$TVP_SOURCE_ROOT/tree-path")"
        ${tools.python}/bin/python3 -B ${../ffi-decimal-source.py} ${tools.bash}/bin/bash ${lib.escapeShellArg (builtins.toJSON final.upstreamSourceLayout)}
      '';
    }
  ];
  upstreamCheck =
    (command "check" ''
      ${make} check_local
    '')
    // {
      enabled = final.doCheck;
    };
  plan = final.productionPlan ++ [
    (steps.split "mpdecimal.finalize")
    (outputs.copyArtifacts { })
    {
      name = "mpdecimal.drop-build-tree";
      tools = [ tools.coreutils ];
      run = ''${tools.coreutils}/bin/rm -rf -- "$out/${checkpoint}"'';
    }
    {
      name = "mpdecimal.relocate";
      tools = [
        tools.python
        tools.binutils
        tools.patchelf
      ];
      run = ''${tools.python}/bin/python3 -B ${../ffi-decimal-output.py} "$out" "$TVP_ARTIFACT_ROOT" ${tools.patchelf}/bin/patchelf ${
        lib.escapeShellArg (
          builtins.toJSON {
            readelf = "${tools.binutils}/bin/readelf";
            shell = "${final.runtime.shell}/bin/bash";
            buildShell = "${tools.bash}/bin/bash";
            paths = map (p: "${p}/bin") final.runtime.tools;
            requiredDirectories = [
              "lib"
              "include"
              "nix-support"
            ];
            requiredFiles = [
              "include/mpdecimal.h"
              "lib/pkgconfig/libmpdec.pc"
            ]
            ++ lib.optional final.buildFeatures.static "lib/libmpdec.a"
            ++ lib.optionals final.buildFeatures.cxx (
              [
                "include/decimal.hh"
                "lib/pkgconfig/libmpdec++.pc"
              ]
              ++ lib.optional final.buildFeatures.static "lib/libmpdec++.a"
            );
            requiredRegular = [
              "include/mpdecimal.h"
              "lib/pkgconfig/libmpdec.pc"
            ]
            ++ lib.optional final.buildFeatures.static "lib/libmpdec.a"
            ++ lib.optionals final.buildFeatures.cxx (
              [
                "include/decimal.hh"
                "lib/pkgconfig/libmpdec++.pc"
              ]
              ++ lib.optional final.buildFeatures.static "lib/libmpdec++.a"
            );
            libtoolData = [ ];
          }
        )
      }'';
    }
    (outputs.strip {
      paths = [ "lib" ];
      elfKinds = [ "runtime" ];
    })
    (
      (outputs.stripArchives {
        paths = [ "lib/libmpdec.a" ] ++ lib.optional final.buildFeatures.cxx "lib/libmpdec++.a";
      })
      // {
        enabled = final.buildFeatures.static;
      }
    )
    ((import ../gdbm/ordinary/rpaths.nix { inherit lib; }) {
      python = tools.python;
      binutils = tools.binutils;
      patchelf = tools.patchelf;
      base = final.base;
      paths = [ "lib" ];
      elfKinds = [ "runtime" ];
      selfLibraryDirectory = true;
      libraries = final.runtime.libraries;
      dlopenDirectories = final.runtime.dlopenDirectories;
    })
    (outputs.development { libraries = [ ]; })
    (outputs.checkLoaderPaths {
      python = tools.python;
      binutils = tools.binutils;
      patchelf = tools.patchelf;
      paths = [ "lib" ];
      elfKinds = [ "runtime" ];
    })
  ];
  tvp.features = final.installedInterface // final.buildFeatures;
  meta = {
    description = "Correctly rounded arbitrary-precision decimal arithmetic libraries";
    homepage = "https://www.bytereef.org/mpdecimal/";
    license = lib.licenses.bsd2;
  };
}

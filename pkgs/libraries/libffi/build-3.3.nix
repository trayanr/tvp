# libffi 3.3 complete installed/source-layout procedure with independent upstream checkpoint.
{
  tvp,
  lib,
  base,
  src,
  version,
  file,
  doCheck ? true,
  cStandard ? "gnu17",
  cFlags ? [ ],
  patches ? [ ],
  testEdits ? [ ],
  upstreamData ? { },
  versionFunction ? false,
  reportedVersion ? null,
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
    } "libffi.${name}";
  make = ''${tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${tools.bash}/bin/bash'';
  checkpoint = "nix-support/libffi-build-tree";
  headerDirectory = "include";
in
{
  pname = "libffi";
  artifactName = "${final.pname}-${final.version}";
  inherit
    base
    src
    version
    file
    doCheck
    cStandard
    cFlags
    patches
    ;
  inherit testEdits upstreamData;
  inherit versionFunction reportedVersion;
  inherit (tools) bash coreutils;
  buildFeatures = {
    cStandard = final.cStandard;
    cFlags = final.cFlags;
    shared = true;
    static = true;
  };
  installedInterface = {
    headersInIncludedir = true;
    variadic = true;
    versionFunction = final.versionFunction;
    compatibilityLib64 = false;
  };
  sourceLayout = {
    libtoolAnchors = {
      "ltmain.sh" = 1;
    };
    selections = [
      "configure"
      "config.sub"
      "config.guess"
      "install-sh"
      "compile"
      "depcomp"
      "missing"
      "ltmain.sh"
      "doc/mdate-sh"
      "libtool-ldflags"
    ];
    shellFragments = {
      "ltmain.sh" = [
        "# Generated from ltmain.m4sh."
        "\n# libtool (GNU libtool) 2.4"
        "\n# libtool (GNU libtool) 2.4.2"
      ];
    };
  };
  upstreamSourceLayout = {
    requireConfigure = false;
    allowBoundShell = true;
    libtoolAnchors = { };
    shellFragments = { };
    selections = [ "testsuite" ];
    edits = [
      {
        path = "testsuite/lib/libffi.exp";
        before = "proc libffi_target_compile { source dest type options } {";
        after = "proc libffi_target_compile { source dest type options } {\n    global env\n    if {[file extension $source] eq \".c\" && $env(TVP_TEST_C_STANDARD) ne \"\"} {\n        lappend options \"additional_flags=-std=$env(TVP_TEST_C_STANDARD)\"\n    }";
        count = 1;
      }
    ]
    ++ final.testEdits;
    documentedData = final.upstreamData;
  };
  configureFlags = [
    "--disable-multi-os-directory"
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
      final.file
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
      export CFLAGS=${
        lib.escapeShellArg (
          lib.concatStringsSep " " (
            [ "-O2" ]
            ++ lib.optional (final.buildFeatures.cStandard != null) "-std=${final.buildFeatures.cStandard}"
            ++ final.buildFeatures.cFlags
          )
        )
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
      name = "libffi.restore-build-tree";
      checkpoint = "${artifact}/${checkpoint}";
    })
    {
      name = "libffi.upstream-source";
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
      export TVP_TEST_C_STANDARD=${
        lib.escapeShellArg (
          if final.buildFeatures.cStandard == null then "" else final.buildFeatures.cStandard
        )
      }
      status=0
      ${tools.coreutils}/bin/timeout --kill-after=10 1800 ${make} check RUNTEST=${
        if final.upstreamCheck.harness == null then
          "runtest"
        else
          lib.escapeShellArg "${final.upstreamCheck.harness}/bin/runtest"
      } || status=$?
      ${tools.findutils}/bin/find . -name libffi.log -type f -exec ${tools.coreutils}/bin/cat {} \;
      exit "$status"
    '')
    // {
      enabled = final.doCheck;
      harness = null;
    };
  plan = final.productionPlan ++ [
    (steps.split "libffi.finalize")
    (outputs.copyArtifacts { })
    {
      name = "libffi.drop-build-tree";
      tools = [ tools.coreutils ];
      run = ''${tools.coreutils}/bin/rm -rf -- "$out/${checkpoint}"'';
    }
    {
      name = "libffi.relocate";
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
              "${headerDirectory}"
              "nix-support"
            ];
            requiredFiles = [
              "lib/libffi.la"
              "${headerDirectory}/ffi.h"
              "${headerDirectory}/ffitarget.h"
              "lib/pkgconfig/libffi.pc"
            ]
            ++ lib.optional final.buildFeatures.static "lib/libffi.a";
            requiredRegular = [
              "lib/libffi.la"
              "${headerDirectory}/ffi.h"
              "${headerDirectory}/ffitarget.h"
              "lib/pkgconfig/libffi.pc"
            ]
            ++ lib.optional final.buildFeatures.static "lib/libffi.a";
            libtoolData = [ "lib/libffi.la" ];
          }
        )
      }'';
    }
    (outputs.strip {
      paths = [ "lib" ];
      elfKinds = [ "runtime" ];
    })
    (
      (outputs.stripArchives { paths = [ "lib/libffi.a" ]; }) // { enabled = final.buildFeatures.static; }
    )
    (outputs.libtool { paths = [ "lib/libffi.la" ]; })
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
  tvp.reportedVersion =
    if final.reportedVersion == null then final.version else final.reportedVersion;
  meta = {
    description = "Foreign function interface library";
    homepage = "https://sourceware.org/libffi/";
    license = lib.licenses.mit;
  };
}

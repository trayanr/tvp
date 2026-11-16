# libyaml 0.0.1: complete production procedure; upstream checks consume its saved checkpoint.
{
  tvp,
  lib,
  base,
  src,
  version,
  file,
  doCheck ? true,
  cStandard ? null,
  commonSymbols ? false,
  patches ? [ ],
  sourceLayout ? { },
  document ? true,
  hasPkgConfig ? true,
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
    } "libyaml.${name}";
  make = ''${tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${tools.bash}/bin/bash'';
  checkpoint = "nix-support/libyaml-build-tree";
in
{
  pname = "libyaml";
  artifactName = "${final.pname}-${final.version}";
  inherit
    base
    src
    version
    file
    doCheck
    cStandard
    commonSymbols
    patches
    document
    hasPkgConfig
    ;
  inherit (tools) bash coreutils;
  sourceLayout = {
    selections = [
      "configure"
      "config/config.guess"
      "config/config.sub"
      "config/depcomp"
      "config/install-sh"
      "config/ltmain.sh"
      "config/missing"
    ];
    shellFragments = {
      "config/ltmain.sh" = [
        "# Generated from ltmain.m4sh."
        ""
      ];
    };
    libtoolAnchors = {
      "config/ltmain.sh" = 1;
    };
  } // sourceLayout;
  buildFeatures = {
    shared = true;
    static = true;
  };
  installedInterface = {
    document = final.document;
    pkgConfig = final.hasPkgConfig;
  };
  features = final.buildFeatures // final.installedInterface;
  configureFlags = [
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
    shell = tools.bash;
    tools = [
      tools.coreutils
      tools.sed
      tools.grep
      tools.gawk
      tools.diffutils
      tools.findutils
    ];
    libraries = [ ];
    dlopenDirectories = [ ];
  };
  productionPlan = steps.sequence [

    (steps.unpack {
      src = final.src;
      tar = tools.gnutar;
      inherit (tools) gzip findutils;
      compression = "gzip";
    })
    (
      (command "prepare" ''
        ${tools.python}/bin/python3 -B ${../dbm-yaml-source.py} ${tools.bash}/bin/bash ${
          lib.escapeShellArg (
            builtins.toJSON (
              final.sourceLayout
              // {
                patches = map (p: "${p}") final.patches;
              }
            )
          )
        }
      '')
      // {
        tools = environment.tools ++ [ tools.python ];
      }
    )
    (command "configure" ''
      export CONFIG_SHELL=${tools.bash}/bin/bash SHELL=${tools.bash}/bin/bash
      export CFLAGS="-O2${
        lib.optionalString (final.cStandard != null) " -std=${final.cStandard}"
      }${lib.optionalString final.commonSymbols " -fcommon"}"
      ./configure --prefix="$out" ${lib.escapeShellArgs final.configureFlags}
    '')
    (command "build" ''
      # The recursive tests directory also declares noinst programs. Build the
      # installed library/headers/metadata here; U keeps the original recursion.
      ${make} SUBDIRS='include src .'
    '')
    (command "install" ''
      ${make} SUBDIRS='include src .' install
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
      name = "libyaml.restore-build-tree";
      checkpoint = "${artifact}/${checkpoint}";
    })
  ];
  upstreamCheck =
    (command "check" ''
      ${make} check
    '')
    // {
      enabled = final.doCheck;
    };
  plan = final.productionPlan ++ [
    (steps.split "libyaml.finalize")
    (outputs.copyArtifacts { })
    {
      name = "libyaml.drop-build-tree";
      tools = [ tools.coreutils ];
      run = ''${tools.coreutils}/bin/rm -rf -- "$out/${checkpoint}"'';
    }
    {
      name = "libyaml.relocate";
      tools = [
        tools.python
        tools.binutils
        tools.patchelf
      ];
      run = ''${tools.python}/bin/python3 -B ${../gdbm/ordinary/output.py} "$out" "$TVP_ARTIFACT_ROOT" ${tools.patchelf}/bin/patchelf ${
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
              "lib/libyaml.a"
              "lib/libyaml.la"
              "include/yaml.h"
            ] ++ lib.optional final.installedInterface.pkgConfig "lib/pkgconfig/yaml-0.1.pc";
            libtoolData = [ "lib/libyaml.la" ];
            requiredRegular = [
              "lib/libyaml.a"
              "lib/libyaml.la"
              "include/yaml.h"
            ] ++ lib.optional final.installedInterface.pkgConfig "lib/pkgconfig/yaml-0.1.pc";
          }
        )
      }'';
    }

    (outputs.strip {
      inherit (tools) python binutils;
      paths = [ "lib" ];
      elfKinds = [ "runtime" ];
    })
    (outputs.stripArchives {
      inherit (tools) python binutils;
      paths = [ "lib/libyaml.a" ];
    })
    (outputs.libtool {
      inherit (tools) python;
      paths = [ "lib/libyaml.la" ];
    })
    ((import ../gdbm/ordinary/rpaths.nix { inherit lib; }) {
      inherit (tools) python binutils patchelf;
      inherit (final) base;
      paths = [ "lib" ];
      elfKinds = [ "runtime" ];
      selfLibraryDirectory = true;
      libraries = final.runtime.libraries;
      dlopenDirectories = final.runtime.dlopenDirectories or [ ];
    })
    (outputs.development {
      inherit (tools) python;
      libraries = [ ];
    })
    (outputs.checkLoaderPaths {
      inherit (tools) python binutils patchelf;
      paths = [ "lib" ];
      elfKinds = [ "runtime" ];
    })
  ];
  tvp.features = final.features // {
    doCheck = final.doCheck;
  };
  meta = {
    description = "C library for parsing and emitting YAML";
    homepage = "https://pyyaml.org/wiki/LibYAML";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
}

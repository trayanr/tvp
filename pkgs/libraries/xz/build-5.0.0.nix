# Complete XZ 5.0.0 procedure: yes/no threading, before the multithread encoder API.
{
  tvp,
  lib,
  base,
  src,
  version,
  less,
  doCheck ? true,
  stripFlags ? [
    "-S"
    "-p"
  ],
  configureFlags ? [ ],
  buildFeatures ? { },
  sourceLayout ? { },
  installedInterface ? { },
}:
final:
let
  context = tvp.builder.forBase final.base;
  inherit (context) steps outputs tools;
  environment = final.base.environment final.environment;
  command = steps.command {
    environment = final.environment;
  };
  make = ''${tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${tools.bash}/bin/bash'';
  checkpoint = "nix-support/xz-build-tree";
  rpaths = paths: {
    name = "output.rpaths";
    tools = [
      tools.python
      tools.binutils
      tools.patchelf
    ];
    run = ''${tools.python}/bin/python3 -B ${../ordinary-compression-rpaths.py} "$out" ${
      lib.escapeShellArg (
        builtins.toJSON {
          inherit paths;
          elfKinds = null;
          libraries = lib.concatMap (
            p: (p.development or { }).libraryDirectories or [ "${lib.getLib p}/lib" ]
          ) final.runtime.libraries;
          dlopenDirectories = final.runtime.dlopenDirectories or [ ];
          baseDirectories = final.base.runtimeDirectories;
          readelf = "${tools.binutils}/bin/readelf";
          patchelf = "${tools.patchelf}/bin/patchelf";
        }
      )
    } ${../../../lib/native-output}'';
  };
in
{
  pname = "xz";
  artifactName = "${final.pname}-${final.version}";
  inherit
    base
    src
    version
    doCheck
    stripFlags
    configureFlags
    less
    ;
  inherit (tools) bash coreutils;
  buildFeatures = {
    multithreadedEncoder = false;
    threading = "yes";
    boundLess = true;
  }
  // buildFeatures;
  sourceLayout = {
    compression = "gzip";
  }
  // sourceLayout;
  installedInterface = {
    elfPaths = [
      "bin/xz"
      "bin/xzdec"
      "bin/lzmadec"
      "bin/lzmainfo"
      "lib"
    ];
    soname = "liblzma.so.5";
    prewriteGuards = true;
  }
  // installedInterface;
  environment = {
    tools = [
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
    shell = tools.bash;
    pager = tools.coreutils;
    less = final.less;
    tools = [
      tools.coreutils
      tools.sed
      tools.grep
      tools.diffutils
    ];
  };
  productionPlan = steps.sequence [
    (steps.unpack {
      src = final.src;
      compression = final.sourceLayout.compression;
    })
    {
      name = "xz.prepare";
      cwd = "source";
      tools = [ tools.python ];
      env = environment.env;
      run = "${tools.python}/bin/python3 -B ${../ordinary-compression-production.py} xz ${tools.bash}/bin/bash ${../compression-source-tree.py}";
    }
    (command "xz.configure" ''
      export CONFIG_SHELL=${tools.bash}/bin/bash
      ./configure --prefix="$out" --enable-shared --enable-static --enable-threads=${lib.escapeShellArg final.buildFeatures.threading} \
        gl_cv_posix_shell=${tools.bash}/bin/bash ${lib.escapeShellArgs final.configureFlags}
    '')
    (command "xz.build" make)
    (command "xz.install" ''
      ${make} install
      mkdir -p "$out/nix-support"
      cp "$TVP_SOURCE_ROOT/source-date-epoch" "$out/nix-support/source-date-epoch"
    '')
    (
      (command "xz.save-build-tree" ''
        ${tools.python}/bin/python3 -B ${../../../lib/build-checkpoint.py} "$TVP_SOURCE_ROOT" "$out/${checkpoint}"
      '')
      // {
        tools = environment.tools ++ [ tools.python ];
      }
    )
  ];
  upstreamPreparation = {
    helper = ../ordinary-compression-test-shells.py;
  };
  upstreamPlan = artifact: [
    (steps.restoreCheckpoint {
      name = "xz.restore-build-tree";
      checkpoint = "${artifact}/${checkpoint}";
    })
    {
      name = "xz.upstream-shells";
      tools = [ tools.python ];
      run = ''
        cd "$(cat "$TVP_SOURCE_ROOT/tree-path")"
        ${tools.python}/bin/python3 -B ${final.upstreamPreparation.helper} xz ${tools.bash}/bin/bash ${../compression-source-tree.py}
      '';
    }
  ];
  upstreamCheck = (command "xz.check" "${make} check") // {
    enabled = final.doCheck;
  };
  plan = final.productionPlan ++ [
    (steps.split "xz.finalize")
    (outputs.copyArtifacts { })
    {
      name = "xz.drop-build-tree";
      tools = [ tools.coreutils ];
      run = ''${tools.coreutils}/bin/rm -rf -- "$out/${checkpoint}"'';
    }
    {
      name = "xz.relocate-runtime";
      tools = [
        tools.python
        tools.patchelf
        tools.binutils
      ];
      run = ''
        ${lib.optionalString final.installedInterface.prewriteGuards ''${tools.python}/bin/python3 -B ${./validate-output.py} ${./installed-guard.py} "$out"''}
        ${tools.python}/bin/python3 -B ${../ordinary-compression-output.py} "$out" "$TVP_ARTIFACT_ROOT" ${tools.patchelf}/bin/patchelf ${
          lib.escapeShellArg (
            builtins.toJSON {
              family = "xz";
              readelf = "${tools.binutils}/bin/readelf";
              buildShell = "${tools.bash}/bin/bash";
              shell = "${final.runtime.shell}/bin/bash";
              pager = "${final.runtime.pager}/bin/cat";
              paths = map (p: "${p}/bin") final.runtime.tools;
            }
          )
        }
        ${lib.optionalString (final.installedInterface.repairPthreadLibs or false) ''
          ${tools.python}/bin/python3 -B ${./repair-pkgconfig.py} \
            "$TVP_ARTIFACT_ROOT/${checkpoint}/source/src/liblzma/Makefile" "$out/lib/pkgconfig/liblzma.pc"
        ''}
        ${lib.optionalString final.buildFeatures.boundLess ''${tools.python}/bin/python3 -B ${./bind-less.py} "$out" ${final.runtime.less}/bin/less''}
      '';
    }
    (outputs.strip {
      flags = final.stripFlags;
      paths = final.installedInterface.elfPaths;
    })
    (outputs.stripArchives {
      paths = [ "lib/liblzma.a" ];
    })
    (outputs.libtool {
      paths = [ "lib/liblzma.la" ];
    })
    (outputs.shebangs {
      paths = [
        "bin/xzdiff"
        "bin/xzgrep"
        "bin/xzmore"
        "bin/xzless"
      ];
      names = [
        "sh"
        "bash"
      ];
      interpreter = "${final.runtime.shell}/bin/bash";
    })
    (rpaths final.installedInterface.elfPaths)
    (outputs.development {
      libraries = [ ];
    })
    {
      name = "output.manuals";
      tools = [
        tools.gzip
        tools.findutils
      ];
      run = ''
        find "$out/share/man" -type f -name '*.1' -print0 | while IFS= read -r -d "" path; do
          ${tools.gzip}/bin/gzip -n -9 "$path"
        done
        find "$out/share/man" -type l -name '*.1' -print0 | while IFS= read -r -d "" path; do
          target=$(readlink "$path")
          rm "$path"
          ln -s "$target.gz" "$path.gz"
        done
      '';
    }
    (outputs.checkSymlinks {
      paths = [
        "lib/liblzma.so"
        "lib/${final.installedInterface.soname}"
        "bin/unxz"
        "bin/xzcat"
        "bin/lzma"
        "bin/unlzma"
        "bin/lzcat"
        "bin/xzcmp"
        "bin/lzgrep"
      ];
    })
    (outputs.checkPaths {
      paths = final.installedInterface.elfPaths;
    })
  ];
  tvp.features.threaded = final.buildFeatures.multithreadedEncoder;
  meta = {
    description = "XZ Utils — general-purpose data compression with the LZMA2 algorithm";
    homepage = "https://tukaani.org/xz/";
    license = lib.licenses.gpl2Plus;
    mainProgram = "xz";
  };
}

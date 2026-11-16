# Flex 2.6: shipped generated parser and explicit skeleton repair facts. Upstream execution is independent.
{
  tvp,
  lib,
  base,
  src,
  version,
  m4,
  file,
  doCheck ? true,
  configureFlags ? [ ],
  patches ? [ ],
  postPatch ? "",
  cStandard ? null,
  rebuildSkeleton ? false,
  checkCFlags ? [ ],
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
  configure = prefix: ''
    export CONFIG_SHELL=${tools.bash}/bin/bash SHELL=${tools.bash}/bin/bash
    ./configure --prefix=${prefix} --enable-shared --enable-static M4=${final.m4}/bin/m4 ${lib.escapeShellArgs final.configureFlags}
  '';
  checkpoint = "nix-support/flex-build-tree";
  elfPaths = [
    "bin"
    "lib"
  ];
in
{
  pname = "flex";
  # Production and installed prefixes have the same byte width; they remain
  # distinct derivations and retain a real artifact/final boundary.
  artifactName = "${final.pname}-${final.version}";
  inherit
    base
    src
    version
    m4
    file
    doCheck
    configureFlags
    patches
    postPatch
    cStandard
    ;
  inherit rebuildSkeleton checkCFlags;
  inherit (tools) bash coreutils;
  buildFeatures = {
    cStandard = final.cStandard;
  };
  sourceLayout = {
    rebuildSkeleton = final.rebuildSkeleton;
  };
  installedInterface = {
    soname = "2";
    yacc = false;
  };
  environment = {
    tools = [
      tools.gnumake
      tools.sed
      tools.grep
      tools.gawk
      tools.diffutils
      tools.findutils
      final.m4
      final.file
    ];
    libraries = [ ];
    overrides.flags.NIX_CFLAGS_COMPILE = lib.optional (
      final.buildFeatures.cStandard != null
    ) "-std=${final.buildFeatures.cStandard}";
  };
  runtime = {
    libraries = [ ];
    dlopenDirectories = [ ];
    shell = tools.bash;
  };
  productionPlan = steps.sequence [
    (steps.unpack {
      src = final.src;
      compression = "gzip";
    })
    (steps.prepareAutotools { name = "flex.prepare"; })
    (steps.shebangs {
      name = "flex.source-shells";
      paths = [ "build-aux" ];
      names = [
        "sh"
        "bash"
      ];
      interpreter = "${tools.bash}/bin/bash";
    })
    (command "flex.patches" ''
      for patch in ${lib.escapeShellArgs (map (p: "${p}") final.patches)}; do
        ${tools.patch}/bin/patch -p1 < "$patch"
      done
      ${final.postPatch}
    '')
    (command "flex.configure" (configure ''"$out"''))
    (
      (command "flex.production-directories" ''
        ${tools.python}/bin/python3 -B ${./production-directories.py} Makefile
      '')
      // {
        tools = environment.tools ++ [ tools.python ];
      }
    )
    (
      (command "flex.skeleton" ''
        ${make} -C src skel.c
        ${tools.coreutils}/bin/touch -r doc/flex.1 src/flex.skl
      '')
      // {
        enabled = final.sourceLayout.rebuildSkeleton;
      }
    )
    (command "flex.build" make)
    (command "flex.install" ''
      ${make} install
      ln -s flex "$out/bin/lex"
      test -s "$out/include/FlexLexer.h"; test -s "$out/lib/libfl.a"; test -s "$out/lib/libfl.la"
      mkdir -p "$out/nix-support"
      cp "$TVP_SOURCE_ROOT/source-date-epoch" "$out/nix-support/source-date-epoch"
    '')
    (
      (command "flex.save-build-tree" ''
        ${tools.python}/bin/python3 -B ${../../../lib/build-checkpoint.py} "$TVP_SOURCE_ROOT" "$out/${checkpoint}"
      '')
      // {
        tools = environment.tools ++ [ tools.python ];
      }
    )
  ];
  upstreamPlan = artifact: [
    (steps.restoreCheckpoint {
      name = "flex.restore-build-tree";
      checkpoint = "${artifact}/${checkpoint}";
    })
    {
      name = "flex.upstream-discovery";
      tools = final.upstreamCheck.tools;
      env = final.upstreamCheck.env;
      # Source-proven configure conditionals choose real counterpart cases.
      # Preserve A's prefix so fixture discovery does not relocate production.
      run = ''
        cd "$(cat "$TVP_SOURCE_ROOT/tree-path")"
        ${configure (lib.escapeShellArg (toString artifact))}
      '';
    }
    (
      let
        shells = steps.shebangs {
          name = "flex.upstream-shells";
          paths = [ "tests" ];
          names = [
            "sh"
            "bash"
          ];
          interpreter = "${tools.bash}/bin/bash";
          cwd = ".";
        };
      in
      shells
      // {
        run = ''
          cd "$(cat "$TVP_SOURCE_ROOT/tree-path")"
        ''
        + shells.run;
      }
    )
  ];
  upstreamCheck =
    (command "flex.check" ''
      export CONFIG_SHELL=${tools.bash}/bin/bash SHELL=${tools.bash}/bin/bash
      ${tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL="$SHELL" TESTSUITEFLAGS="-j$NIX_BUILD_CORES" ${
        lib.optionalString (
          final.checkCFlags != [ ]
        ) ''CFLAGS="-g -O2 ${lib.concatStringsSep " " final.checkCFlags}"''
      } check
    '')
    // {
      enabled = final.doCheck;
    };
  plan = final.productionPlan ++ [
    (steps.split "flex.finalize")
    (outputs.copyArtifacts { })
    {
      name = "flex.drop-build-tree";
      tools = [ tools.coreutils ];
      run = ''${tools.coreutils}/bin/rm -rf -- "$out/${checkpoint}"'';
    }
    {
      name = "flex.relocate";
      tools = [
        tools.python
        tools.patchelf
      ];
      run = ''${tools.python}/bin/python3 -B ${../../../lib/relocate.py} "$out" "$TVP_ARTIFACT_ROOT" ${tools.patchelf}/bin/patchelf'';
    }
    (outputs.strip { paths = elfPaths; })
    (outputs.stripArchives { paths = [ "lib/libfl.a" ]; })
    (outputs.rpaths {
      paths = elfPaths;
      libraries = final.runtime.libraries;
      dlopenDirectories = final.runtime.dlopenDirectories;
    })
    (outputs.development { libraries = [ ]; })
    (outputs.checkSymlinks {
      paths = [
        "lib/libfl.so"
        "lib/libfl.so.2"
        "bin/lex"
      ];
    })
    (outputs.checkPaths { paths = elfPaths; })
  ];
  meta = {
    homepage = "https://github.com/westes/flex";
    description = "Lexical analyser generator for C and C++";
    license = lib.licenses.bsd2;
    mainProgram = "flex";
  };
}

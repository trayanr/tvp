# Bison 3.3.2-era installed skeleton layout. Upstream execution is independent.
{
  tvp,
  lib,
  base,
  src,
  version,
  m4,
  perl,
  doCheck ? true,
  configureFlags ? [ ],
  patches ? [ ],
  postPatch ? "",
  cStandard ? null,
  upstreamPrerequisites ? [ ],
  upstreamPatches ? [ ],
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
    ./configure --prefix=${prefix}  M4=${final.m4}/bin/m4 ${lib.escapeShellArgs final.configureFlags}
  '';
  checkpoint = "nix-support/bison-build-tree";
  elfPaths = [ "bin" ];
in
{
  pname = "bison";
  # Production and installed prefixes have the same byte width; they remain
  # distinct derivations and retain a real artifact/final boundary.
  artifactName = "${final.pname}-${final.version}";
  inherit
    base
    src
    version
    m4
    perl
    doCheck
    configureFlags
    patches
    postPatch
    cStandard
    ;
  inherit upstreamPrerequisites upstreamPatches;
  inherit (tools) bash coreutils;
  buildFeatures = {
    cStandard = final.cStandard;
  };
  installedInterface = {
    skeletonDirectory = "share/bison/skeletons";
    yacc = true;
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
      final.perl
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
    (steps.prepareAutotools { name = "bison.prepare"; })
    (command "bison.patches" ''
      for patch in ${lib.escapeShellArgs (map (p: "${p}") final.patches)}; do
        ${tools.patch}/bin/patch -p1 < "$patch"
      done
      ${final.postPatch}
    '')
    (command "bison.configure" (configure ''"$out"''))
    (command "bison.build" make)
    (command "bison.install" ''
      ${make} install
      test -s "$out/${final.installedInterface.skeletonDirectory}/yacc.c"
      mkdir -p "$out/nix-support"
      cp "$TVP_SOURCE_ROOT/source-date-epoch" "$out/nix-support/source-date-epoch"
    '')
    (
      (command "bison.save-build-tree" ''
        ${tools.python}/bin/python3 -B ${../../../lib/build-checkpoint.py} "$TVP_SOURCE_ROOT" "$out/${checkpoint}"
      '')
      // {
        tools = environment.tools ++ [ tools.python ];
      }
    )
  ];
  upstreamPlan = artifact: [
    (steps.restoreCheckpoint {
      name = "bison.restore-build-tree";
      checkpoint = "${artifact}/${checkpoint}";
    })
    {
      name = "bison.upstream-discovery";
      tools = final.upstreamCheck.tools ++ [ tools.patch ];
      env = final.upstreamCheck.env;
      # Source-proven configure conditionals choose real counterpart cases.
      # Preserve A's prefix so fixture discovery does not relocate production.
      run = ''
        cd "$(cat "$TVP_SOURCE_ROOT/tree-path")"
        for patch in ${lib.escapeShellArgs (map (p: "${p.file}") final.upstreamPatches)}; do
          ${tools.patch}/bin/patch -p1 < "$patch"
        done
        ${configure (lib.escapeShellArg (toString artifact))}
      '';
    }
  ];
  upstreamCheck =
    (command "bison.check" ''
      export CONFIG_SHELL=${tools.bash}/bin/bash SHELL=${tools.bash}/bin/bash
      ${lib.optionalString (
        final.upstreamPrerequisites != [ ]
      ) "${tools.gnumake}/bin/make ${lib.escapeShellArgs final.upstreamPrerequisites}"}
      ${tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL="$SHELL" TESTSUITEFLAGS="-j$NIX_BUILD_CORES"  check
    '')
    // {
      enabled = final.doCheck;
    };
  plan = final.productionPlan ++ [
    (steps.split "bison.finalize")
    (outputs.copyArtifacts { })
    {
      name = "bison.drop-build-tree";
      tools = [ tools.coreutils ];
      run = ''${tools.coreutils}/bin/rm -rf -- "$out/${checkpoint}"'';
    }
    (outputs.shebangs {
      paths = [ "bin/yacc" ];
      names = [ "sh" ];
      interpreter = "${final.runtime.shell}/bin/bash";
    })
    {
      name = "bison.relocate";
      tools = [
        tools.python
        tools.patchelf
      ];
      run = ''${tools.python}/bin/python3 -B ${../../../lib/relocate.py} "$out" "$TVP_ARTIFACT_ROOT" ${tools.patchelf}/bin/patchelf'';
    }
    (outputs.strip { paths = elfPaths; })
    (outputs.rpaths {
      paths = elfPaths;
      libraries = final.runtime.libraries;
      dlopenDirectories = final.runtime.dlopenDirectories;
    })
    (outputs.development { libraries = [ ]; })
    (outputs.checkPaths { paths = elfPaths; })
  ];
  meta = {
    homepage = "https://www.gnu.org/software/bison/";
    description = "GNU parser generator";
    license = lib.licenses.gpl3Plus;
    mainProgram = "bison";
  };
}

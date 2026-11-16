# Gzip 1.13–1.15: one complete production procedure and installed helper layout.
{
  tvp,
  lib,
  base,
  src,
  version,
  pager,
  doCheck ? true,
  configureFlags ? [ ],
  upstreamPagerShim ? false,
}:
final:
let
  context = tvp.builder.forBase final.base;
  inherit (context) steps outputs tools;
  checkpoint = "nix-support/gzip-build-tree";
  upstreamEnvironment = final.base.environment (
    final.environment
    // {
      tools = final.environment.tools ++ [ final.runtime.pager ];
    }
  );
  command =
    name:
    steps.command {
      environment = final.environment;
    } "gzip.${name}";
  make = ''${tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${tools.bash}/bin/bash'';
in
{
  pname = "gzip";
  artifactName = "${final.pname}-${final.version}";
  inherit
    base
    src
    version
    pager
    doCheck
    configureFlags
    upstreamPagerShim
    ;
  inherit (tools) bash coreutils;
  dependencyProviders.pager = final.pager;
  sourceLayout.compression = "xz";
  installedInterface = {
    helpers = [
      "gunzip"
      "zcat"
      "gzexe"
      "zcmp"
      "zdiff"
      "zegrep"
      "zfgrep"
      "zforce"
      "zgrep"
      "zless"
      "zmore"
      "znew"
      "uncompress"
    ];
    gzexeSkip = 49;
  };
  environment = {
    tools = [
      tools.gnumake
      tools.findutils
      tools.sed
      tools.grep
      tools.gawk
      tools.diffutils
    ];
    libraries = [ ];
  };
  runtime = {
    libraries = [ ];
    shell = tools.bash;
    grep = tools.grep;
    pager = final.pager;
    tools = [
      tools.coreutils
      tools.sed
      final.runtime.grep
      tools.diffutils
      final.runtime.pager
      final.runtime.shell
    ];
  };
  productionPlan = steps.sequence [
    (steps.unpack {
      src = final.src;
      compression = "xz";
    })
    (steps.prepareAutotools { name = "gzip.prepare"; })
    (command "configure" ''
      export CONFIG_SHELL=${tools.bash}/bin/bash SHELL=${tools.bash}/bin/bash
      # Install the pager frontend without making its runtime provider a build
      # input. Finalization binds the selected pager and shell.
      ./configure --prefix="$out" LESS=less GREP=${tools.grep}/bin/grep ${lib.escapeShellArgs final.configureFlags}
    '')
    (command "build" make)
    (command "install" ''
      ${make} install
      mkdir -p "$out/nix-support"
      cp "$TVP_SOURCE_ROOT/source-date-epoch" "$out/nix-support/source-date-epoch"
    '')
    (command "save-build-tree" ''
      ${tools.python}/bin/python3 -B ${../../../lib/build-checkpoint.py} "$TVP_SOURCE_ROOT" "$out/${checkpoint}"
    '')
  ];
  upstreamPlan = artifact: [
    (steps.restoreCheckpoint {
      name = "gzip.restore-build-tree";
      checkpoint = "${artifact}/${checkpoint}";
    })
  ];
  upstreamCheck =
    (command "check" ''
      export CONFIG_SHELL=${tools.bash}/bin/bash SHELL=${tools.bash}/bin/bash
      ${lib.optionalString final.upstreamPagerShim ''
        # The historical check profile supplies a noninteractive `more` provider.
        mkdir -p test-pager/bin
        printf '#!${tools.bash}/bin/bash\nexec ${final.runtime.pager}/bin/less "$@"\n' > test-pager/bin/more
        chmod +x test-pager/bin/more
        export PATH="$PWD/test-pager/bin:$PATH"
      ''}
      status=0
      ${make} check || status=$?
      ${tools.findutils}/bin/find . \( -name 'test-suite.log' -o -name '*.trs' \) -exec ${tools.coreutils}/bin/cat {} \; >&2
      exit "$status"
    '')
    // {
      enabled = final.doCheck;
      tools = upstreamEnvironment.tools;
      env = upstreamEnvironment.env;
    };
  plan = final.productionPlan ++ [
    (steps.split "gzip.finalize")
    (outputs.copyArtifacts { preserveHardlinks = false; })
    {
      name = "gzip.drop-build-tree";
      tools = [ tools.coreutils ];
      run = ''${tools.coreutils}/bin/rm -rf -- "$out/${checkpoint}"'';
    }
    {
      name = "gzip.relocate";
      tools = [ tools.python ];
      run = ''${tools.python}/bin/python3 -B ${../owned-split-output.py} "$out" "$TVP_ARTIFACT_ROOT" '{}' ${../../../lib/installed-tree.py}'';
    }
    {
      name = "gzip.bind-helpers";
      tools = [ tools.python ];
      run = ''${tools.python}/bin/python3 -B ${./bind-helpers.py} "$out" ${
        lib.escapeShellArg (
          builtins.toJSON {
            helpers = final.installedInterface.helpers;
            skip = final.installedInterface.gzexeSkip;
            shell = "${final.runtime.shell}/bin/bash";
            buildGrep = "${tools.grep}/bin/grep";
            grep = "${final.runtime.grep}/bin/grep";
            pager = "${final.runtime.pager}/bin/less";
            paths = map (p: "${p}/bin") final.runtime.tools;
          }
        )
      }'';
    }
    (outputs.strip { paths = [ "bin" ]; })
    (outputs.rpaths {
      paths = [ "bin" ];
      libraries = final.runtime.libraries;
      dlopenDirectories = final.runtime.dlopenDirectories or [ ];
    })
    (outputs.development { libraries = [ ]; })
    (outputs.checkPaths { paths = [ "bin" ]; })
  ];
  meta = {
    description = "GNU gzip compression utilities";
    homepage = "https://www.gnu.org/software/gzip/";
    license = lib.licenses.gpl3Plus;
    platforms = [ "x86_64-linux" ];
    mainProgram = "gzip";
  };
}

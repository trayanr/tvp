{
  tvp,
  lib,
  base,
  src,
  version,
  binutils,
  patches ? [ ],
  doCheck ? true,
  configureFlags ? [ ],
  stripFlags ? [
    "-S"
    "-p"
  ],
}:

final:
let
  context = tvp.builder.forBase final.base;
  inherit (context) steps outputs;
  baseTools = context.tools;
  inherit (final)
    bash
    coreutils
    gnumake
    gnutar
    gzip
    xz
    patch
    sed
    grep
    gawk
    diffutils
    findutils
    python
    patchelf
    ;
  environment = final.base.environment final.environment;
  productionMake =
    target:
    lib.concatMapStringsSep "\n"
      (
        directory:
        let
          localTarget =
            if directory == "." then (if target == "all" then "all-am" else "install-am") else target;
        in
        ''${final.gnumake}/bin/make -j"$NIX_BUILD_CORES" -C ${lib.escapeShellArg directory} SHELL=${final.bash}/bin/bash ${localTarget}''
      )
      [
        "lib"
        "src"
        "."
      ];
  command =
    name: run:
    environment
    // {
      inherit name run;
      cwd = "source";
    };
in
{
  pname = "patch";
  bash = baseTools.bash;
  coreutils = baseTools.coreutils;
  gnumake = baseTools.gnumake;
  gnutar = baseTools.gnutar;
  gzip = baseTools.gzip;
  xz = baseTools.xz;
  patch = baseTools.patch;
  sed = baseTools.sed;
  grep = baseTools.grep;
  gawk = baseTools.gawk;
  diffutils = baseTools.diffutils;
  findutils = baseTools.findutils;
  python = baseTools.python;
  patchelf = baseTools.patchelf;

  # Equal-width compiled-prefix ABI; the artifact remains a distinct producer.
  artifactName = "${final.pname}-${final.version}";
  inherit
    base
    src
    version
    binutils
    doCheck
    configureFlags
    stripFlags
    patches
    ;
  environment = {
    tools = [
      final.gnumake
      final.sed
      final.grep
      final.gawk
      final.diffutils
      final.findutils
    ];
    libraries = [ ];
  };
  runtime = {
    libraries = [ ];
    dlopenDirectories = [ ];
  };
  upstreamCheck =
    (command "patch.check" ''
      status=0
      ${final.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${final.bash}/bin/bash check || status=$?
      if (( status )); then cat tests/test-suite.log >&2 || :; fi
      exit "$status"
    '')
    // {
      enabled = final.doCheck;
    };
  # Caller production patches run before configure; only this fixture patch is test-only.
  productionPatches = lib.filter (
    p: toString p != toString ./patches/bad-filenames-input.patch
  ) final.patches;
  testPatches = lib.filter (
    p: toString p == toString ./patches/bad-filenames-input.patch
  ) final.patches;
  originalPlan = steps.sequence [
    (steps.unpack {
      src = final.src;
      xz = final.xz;
      tar = final.gnutar;
      findutils = final.findutils;
    })
    (command "patch.sources" ''
      for file in ${lib.escapeShellArgs (map (p: "${p}") final.productionPatches)}; do
        ${final.patch}/bin/patch -p1 < "$file"
      done
    '')
    (steps.shebangs {
      name = "patch.source-shells";
      python = final.python;
      paths = [
        "configure"
        "build-aux"
      ];
      names = [
        "sh"
        "bash"
      ];
      interpreter = "${final.bash}/bin/bash";
    })
    (command "patch.configure" ''
      export CONFIG_SHELL=${final.bash}/bin/bash
      ${final.bash}/bin/bash ./configure --prefix="$out" --disable-dependency-tracking \
        ${lib.escapeShellArgs final.configureFlags}
    '')
    (command "patch.build" (productionMake "all"))
    (command "patch.install" (productionMake "install"))
    (steps.split "patch.finalize")
    (outputs.copyArtifacts { coreutils = final.coreutils; })
    {
      name = "patch.relocate";
      tools = [ final.python ];
      run = ''${final.python}/bin/python3 -B ${../owned-split-output.py} "$out" "$TVP_ARTIFACT_ROOT" ${
        lib.escapeShellArg (
          builtins.toJSON {
            text = [ ];
            slots = [ ];
            fixed = [ ];
          }
        )
      } ${../../../lib/installed-tree.py}'';
    }
    {
      name = "output.manuals";
      tools = [ final.gzip ];
      run = ''
        ${final.gzip}/bin/gzip -n -9 "$out/share/man/man1/patch.1"
      '';
    }
    (outputs.strip {
      python = final.python;
      binutils = final.binutils;
      paths = [ "bin/patch" ];
      flags = final.stripFlags;
    })
    (outputs.rpaths {
      python = final.python;
      binutils = final.binutils;
      patchelf = final.patchelf;
      base = final.base;
      paths = [ "bin/patch" ];
      libraries = final.runtime.libraries;
      dlopenDirectories = final.runtime.dlopenDirectories or [ ];
    })
    (outputs.checkPaths {
      python = final.python;
      binutils = final.binutils;
      patchelf = final.patchelf;
      paths = [ "bin/patch" ];
    })
  ];
  meta = {
    description = "GNU patch application utility";
    license = lib.licenses.gpl3Plus;
    platforms = [ "x86_64-linux" ];
    mainProgram = "patch";
  };
  upstreamPlan = artifact: [
    {
      name = "patch.restore-build-tree";
      tools = [ baseTools.python ];
      run = ''
        ${baseTools.python}/bin/python3 -B ${../utilities-restore.py} ${artifact}/nix-support/patch-build-tree "$TVP_SOURCE_ROOT"
        printf '%s\n' ${artifact} > "$TVP_SOURCE_ROOT/production-artifact"
      '';
    }

    {
      name = "patch.upstream-frontends";
      tools = [
        final.python
        final.patch
      ];
      run = ''
        cd "$(cat "$TVP_SOURCE_ROOT/tree-path")"
        for file in ${
          lib.escapeShellArgs (map (p: "${p}") final.testPatches)
        }; do ${final.patch}/bin/patch -p1 < "$file"; done
        ${(steps.shebangs {
          name = "patch.test-shells";
          python = final.python;
          paths = [ "tests" ];
          names = [
            "sh"
            "bash"
          ];
          interpreter = "${final.bash}/bin/bash";
        }).run
        }
      '';
    }
  ];
  plan =
    let
      parts = steps.partition final.originalPlan;
      production =
        builtins.filter
          (
            step:
            !(builtins.elem step.name [
              "patch.check"
            ])
          )
          (
            builtins.filter (step: step.name != "patch.sources" || final.productionPatches != [ ]) parts.first
          );
    in
    production
    ++ [
      {
        name = "patch.save-build-tree";
        tools = [
          baseTools.python
          final.coreutils
        ];
        run = ''
          ${baseTools.python}/bin/python3 -B ${../../../lib/build-checkpoint.py} "$TVP_SOURCE_ROOT" "$out/nix-support/patch-build-tree"
        '';
      }
    ]
    ++ (lib.optional parts.split (steps.split "patch.finalize"))
    ++ [
      (builtins.head parts.second)
      {
        name = "patch.drop-build-tree";
        tools = [ final.coreutils ];
        run = ''${final.coreutils}/bin/rm -rf -- "$out/nix-support/patch-build-tree"'';
      }
    ]
    ++ builtins.tail parts.second;

}

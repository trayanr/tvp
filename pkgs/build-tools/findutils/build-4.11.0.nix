# Native ordinary 4.11.0 route; serves 4.11.0 only. Retained older and
# construction procedures keep their own host generations and feature profiles.
{
  tvp,
  lib,
  base,
  src,
  version,
  coreutils,
  doCheck ? true,
}:

final:
let
  context = tvp.builder.forBase final.base;
  inherit (context) steps outputs tools;

  productionMake =
    target:
    lib.concatMapStringsSep "\n"
      (
        directory:
        let
          noTestRecursion = lib.optionalString (
            directory == "."
            || builtins.elem directory [
              "find"
              "xargs"
              "locate"
            ]
          ) " SUBDIRS=.";
          noTestPrograms = lib.optionalString (directory == "find") " noinst_PROGRAMS=";
        in
        ''${tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" -C ${lib.escapeShellArg directory} SHELL=${final.bash}/bin/bash${noTestPrograms} ${target}${noTestRecursion}''
      )
      [
        "."
        "gl"
        "build-aux"
        "lib"
        "find"
        "xargs"
        "locate"
        "doc"
        "po"
        "m4"
      ];
  checkpoint = "nix-support/findutils-build-tree";
  environment = final.base.environment final.environment;
  command =
    name: run:
    environment
    // {
      inherit name run;
      cwd = "source";
    };
in
{
  pname = "findutils";
  bash = tools.bash;
  inherit doCheck;
  # Equal-width compiled-prefix ABI; the artifact remains a distinct producer.
  artifactName = "${final.pname}-${final.version}";
  inherit
    base
    src
    version
    ;
  coreutils = tools.coreutils;
  helperCoreutils = coreutils;
  dependencyProviders = {
    coreutils = final.helperCoreutils;
  };
  environment = {
    tools = [
      tools.gnumake
      tools.sed
      tools.grep
      tools.gawk
      tools.diffutils
      tools.findutils
      tools.perl
    ];
    libraries = [ ];
  };
  runtime.libraries = [ ];

  installedInterface = {
    ordinaryControls = false;
    hasNls = true;
  };
  upstreamPlan = artifact: [
    {
      name = "findutils.restore-build-tree";
      tools = [ tools.python ];
      run = ''${tools.python}/bin/python3 -B ${../text-tool-restore.py} ${artifact}/${checkpoint} "$TVP_SOURCE_ROOT"'';
    }

    {
      name = "findutils.upstream-frontends";
      tools = [
        tools.python
        tools.perl
      ];
      run = ''
        cd "$(cat "$TVP_SOURCE_ROOT/tree-path")"
        ${tools.python}/bin/python3 -B ${../ordinary-text-upstream-source.py} ${final.bash}/bin/bash ${tools.perl}/bin/perl '${builtins.toJSON [ "tests" ]}'
      '';
    }
  ];
  upstreamCheck =
    (command "findutils.check" ''
      ${tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" check
    '')
    // {
      enabled = final.doCheck;
    };
  plan = steps.sequence [
    (steps.unpack {
      src = final.src;

    })
    (steps.prepareAutotools {
      name = "findutils.prepare";

      base = final.base;
    })
    (steps.shebangs {
      name = "findutils.source-shells";

      paths = [ "build-aux" ];
      names = [
        "sh"
        "bash"
      ];
      interpreter = "${final.bash}/bin/bash";
    })
    (command "findutils.configure" ''
      export CONFIG_SHELL=${final.bash}/bin/bash FORCE_UNSAFE_CONFIGURE=1
      export SORT=${final.helperCoreutils}/bin/sort
      ./configure --prefix="$out" --enable-nls
      grep '^#define ENABLE_NLS 1' config.h
    '')
    (command "findutils.build" (productionMake "all"))
    (command "findutils.install" ''
      ${productionMake "install"}
      mkdir -p "$out/nix-support"
      cp "$TVP_SOURCE_ROOT/source-date-epoch" "$out/nix-support/source-date-epoch"
      cp config.h "$out/nix-support/config.h"
      grep -Ex 'gt_cv_func_gnugettext[0-9]+_libc=yes' config.log > "$out/nix-support/gettext-libc"
    '')

    {
      name = "findutils.save-build-tree";
      tools = [ tools.python ];
      run = ''${tools.python}/bin/python3 -B ${../../../lib/build-checkpoint.py} "$TVP_SOURCE_ROOT" "$out/${checkpoint}"'';
    }
    (steps.split "findutils.finalize")
    (outputs.copyArtifacts { coreutils = final.coreutils; })
    {
      name = "findutils.drop-build-tree";
      tools = [ tools.coreutils ];
      run = ''${tools.coreutils}/bin/rm -rf -- "$out/${checkpoint}"'';
    }

    {
      name = "findutils.relocate";
      tools = [ tools.python ];
      run = ''${tools.python}/bin/python3 -B ${../owned-split-output.py} "$out" "$TVP_ARTIFACT_ROOT" ${
        lib.escapeShellArg (
          builtins.toJSON {
            text = [ ];
            slots = [ ];
            fixed = [ ];
          }
        )
      } ${../../../lib/installed-tree.py}'';
    }
    (outputs.shebangs {
      paths = [ "bin/updatedb" ];
      names = [
        "sh"
        "bash"
      ];
      interpreter = "${final.bash}/bin/bash";
    })
    {
      name = "output.manuals";
      tools = [
        tools.gzip
        tools.findutils
      ];
      run = ''
        while IFS= read -r -d "" manual; do
          ${tools.gzip}/bin/gzip -n -9 "$manual"
        done < <(${tools.findutils}/bin/find "$out/share/man" -type f ! -name '*.gz' -print0)
        while IFS= read -r -d "" manual; do
          target=$(readlink "$manual")
          rm "$manual"
          ln -s "$target.gz" "$manual.gz"
        done < <(${tools.findutils}/bin/find "$out/share/man" -type l ! -name '*.gz' -print0)
      '';
    }
    (outputs.strip {
      paths = [
        "bin"
        "libexec"
      ];
      elfKinds = [ "runtime" ];
    })
    (outputs.rpaths {
      base = final.base;
      libraries = final.runtime.libraries;
      dlopenDirectories = final.runtime.dlopenDirectories or [ ];
      paths = [
        "bin"
        "libexec"
      ];
      elfKinds = [ "runtime" ];
    })
    (outputs.checkPaths {
      paths = [
        "bin"
        "libexec"
      ];
      elfKinds = [ "runtime" ];
    })
  ];
  meta = {
    description = "GNU findutils utilities";
    license = lib.licenses.gpl3Plus;
    platforms = [ "x86_64-linux" ];
  };
}

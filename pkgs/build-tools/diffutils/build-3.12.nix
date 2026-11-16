# Native ordinary 3.12 route; serves 3.12 only. Retained older and
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
          noTestRecursion = lib.optionalString (directory == ".") " SUBDIRS=.";
        in
        ''${tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" -C ${lib.escapeShellArg directory} SHELL=${final.bash}/bin/bash ${target}${noTestRecursion}''
      )
      [
        "."
        "lib"
        "src"
        "doc"
        "man"
        "po"
      ];
  checkpoint = "nix-support/diffutils-build-tree";
  environment = final.base.environment final.environment;
  command = steps.command {
    environment = final.environment;
  };
in
{
  pname = "diffutils";
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
    (steps.restoreCheckpoint {
      name = "diffutils.restore-build-tree";
      checkpoint = "${artifact}/${checkpoint}";
    })

    {
      name = "diffutils.upstream-frontends";
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
    (command "diffutils.check" ''
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
      name = "diffutils.prepare";

      base = final.base;
    })
    (steps.shebangs {
      name = "diffutils.source-shells";

      paths = [ "build-aux" ];
      names = [
        "sh"
        "bash"
      ];
      interpreter = "${final.bash}/bin/bash";
    })
    (command "diffutils.configure" ''
      export CONFIG_SHELL=${final.bash}/bin/bash FORCE_UNSAFE_CONFIGURE=1
      export PR_PROGRAM=${final.helperCoreutils}/bin/pr
      ./configure --prefix="$out" --enable-nls
      grep '^#define ENABLE_NLS 1' lib/config.h
    '')
    (command "diffutils.build" (productionMake "all"))
    (command "diffutils.install" ''
      ${productionMake "install"}
      mkdir -p "$out/nix-support"
      cp "$TVP_SOURCE_ROOT/source-date-epoch" "$out/nix-support/source-date-epoch"
      cp lib/config.h "$out/nix-support/config.h"
      grep -Ex 'gt_cv_func_gnugettext[0-9]+_libc=yes' config.log > "$out/nix-support/gettext-libc"
    '')

    {
      name = "diffutils.save-build-tree";
      tools = [ tools.python ];
      run = ''${tools.python}/bin/python3 -B ${../../../lib/build-checkpoint.py} "$TVP_SOURCE_ROOT" "$out/${checkpoint}"'';
    }
    (steps.split "diffutils.finalize")
    (outputs.copyArtifacts { coreutils = final.coreutils; })
    {
      name = "diffutils.drop-build-tree";
      tools = [ tools.coreutils ];
      run = ''${tools.coreutils}/bin/rm -rf -- "$out/${checkpoint}"'';
    }

    {
      name = "diffutils.relocate";
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
      paths = [ "bin" ];
      elfKinds = [ "runtime" ];
    })
    (outputs.rpaths {
      base = final.base;
      libraries = final.runtime.libraries;
      dlopenDirectories = final.runtime.dlopenDirectories or [ ];
      paths = [ "bin" ];
      elfKinds = [ "runtime" ];
    })
    (outputs.checkPaths {
      paths = [ "bin" ];
      elfKinds = [ "runtime" ];
    })
  ];
  meta = {
    description = "GNU diffutils utilities";
    license = lib.licenses.gpl3Plus;
    platforms = [ "x86_64-linux" ];
  };
}

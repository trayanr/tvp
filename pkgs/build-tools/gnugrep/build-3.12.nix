# Native ordinary 3.12 boundary: complete source-GNU procedure for 3.12 only.
# Earlier releases and captured construction generations retain independent routes.
{
  tvp,
  lib,
  base,
  src,
  version,
  pcre2,
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
        "po"
        "lib"
        "doc"
        "src"
      ];
  checkpoint = "nix-support/gnugrep-build-tree";
  command =
    name:
    steps.command {
      environment = final.environment;
    } "gnugrep.${name}";
in
{
  pname = "gnugrep";
  bash = tools.bash;
  inherit doCheck;
  inherit pcre2;
  inherit (tools) coreutils;
  # Equal-width compiled-prefix ABI; the artifact remains a distinct producer.
  artifactName = "${final.pname}-${final.version}";
  inherit
    base
    src
    version
    ;
  dependencyProviders = {
    pcre2 = final.pcre2;
  };
  environment = {
    tools = [
      tools.gnumake
      tools.sed
      tools.grep
      tools.gawk
      tools.diffutils
      tools.findutils
    ];
    libraries = [ final.pcre2 ];
  };
  runtime.libraries = [ final.pcre2 ];

  installedInterface = {
    ordinaryControls = false;
    hasNls = true;
  };
  upstreamPlan = artifact: [
    (steps.restoreCheckpoint {
      name = "gnugrep.restore-build-tree";
      checkpoint = "${artifact}/${checkpoint}";
    })

    {
      name = "gnugrep.upstream-frontends";
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
    (command "check" ''
      ${tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${final.bash}/bin/bash check
    '')
    // {
      enabled = final.doCheck;
    };
  plan = steps.sequence [
    (steps.unpack {
      src = final.src;

      compression = "xz";
    })
    (steps.prepareAutotools {
      name = "gnugrep.prepare";

      base = final.base;
    })
    (steps.shebangs {
      name = "gnugrep.source-shells";

      paths = [ "build-aux" ];
      names = [
        "sh"
        "bash"
      ];
      interpreter = "${final.bash}/bin/bash";
    })
    (command "configure" ''
      export CONFIG_SHELL=${final.bash}/bin/bash SHELL=${final.bash}/bin/bash FORCE_UNSAFE_CONFIGURE=1
      ./configure --prefix="$out" --enable-nls --enable-perl-regexp
      grep '^#define HAVE_LIBPCRE 1' config.h
      grep '^#define ENABLE_NLS 1' config.h
    '')
    (command "build" (productionMake "all"))
    (command "install" ''
      ${productionMake "install"}
      mkdir -p "$out/nix-support"
      cp "$TVP_SOURCE_ROOT/source-date-epoch" "$out/nix-support/source-date-epoch"
      cp config.h "$out/nix-support/config.h"
      grep -Ex 'gt_cv_func_gnugettext[0-9]+_libc=yes' config.log > "$out/nix-support/gettext-libc"
    '')

    {
      name = "gnugrep.save-build-tree";
      tools = [ tools.python ];
      run = ''${tools.python}/bin/python3 -B ${../../../lib/build-checkpoint.py} "$TVP_SOURCE_ROOT" "$out/${checkpoint}"'';
    }
    (steps.split "gnugrep.finalize")
    (outputs.copyArtifacts { coreutils = final.coreutils; })
    {
      name = "gnugrep.drop-build-tree";
      tools = [ tools.coreutils ];
      run = ''${tools.coreutils}/bin/rm -rf -- "$out/${checkpoint}"'';
    }

    {
      name = "gnugrep.relocate";
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
      paths = [ "bin" ];
      names = [
        "sh"
        "bash"
      ];
      interpreter = "${final.bash}/bin/bash";
    })
    (outputs.strip {
      paths = [ "bin" ];
    })
    (outputs.rpaths {
      base = final.base;
      libraries = final.runtime.libraries;
      dlopenDirectories = final.runtime.dlopenDirectories or [ ];
      paths = [ "bin" ];
    })
    (outputs.development {
      libraries = [ ];
    })
    (outputs.checkPaths {
      paths = [ "bin" ];
    })
  ];
  tvp.features = {
    pcre = true;
    nls = true;
  };
  meta = {
    description = "GNU pattern matching utilities";
    license = lib.licenses.gpl3Plus;
    platforms = [ "x86_64-linux" ];
  };
}

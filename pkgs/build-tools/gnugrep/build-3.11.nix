# Grep 3.11 retains historical -m overread and obsolete byte-offset options.
# Independent ordinary procedure for 3.11 only.
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
          localTarget =
            if directory == "." then (if target == "all" then "all-am" else "install-am") else target;
        in
        ''${tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" -C ${lib.escapeShellArg directory} SHELL=${final.bash}/bin/bash ${localTarget}''
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
    name: run:
    (final.base.environment final.environment)
    // {
      name = "gnugrep.${name}";
      cwd = "source";
      inherit run;
    };
  rpaths =
    {
      python,
      binutils,
      patchelf,
      base,
      paths,
      libraries,
      dlopenDirectories ? [ ],
      elfKinds ? null,
    }:
    {
      name = "output.rpaths";
      tools = [
        python
        binutils
        patchelf
      ];
      run = ''${python}/bin/python3 -B ${../../libraries/ordinary-compression-rpaths.py} "$out" ${
        lib.escapeShellArg (
          builtins.toJSON {
            inherit paths dlopenDirectories elfKinds;
            libraries = lib.concatMap (
              p: (p.development or { }).libraryDirectories or [ "${lib.getLib p}/lib" ]
            ) libraries;
            baseDirectories = base.runtimeDirectories;
            readelf = "${binutils}/bin/readelf";
            patchelf = "${patchelf}/bin/patchelf";
          }
        )
      } ${../../../lib/native-output}'';
    };

in
{
  pname = "gnugrep";
  bash = tools.bash;
  inherit (tools) coreutils;
  inherit
    base
    src
    version
    ;
  inherit
    pcre2
    doCheck
    ;
  configureFlags = [ ];
  stripFlags = [
    "-S"
    "-p"
  ];
  dependencyProviders = {
    pcre2 = final.pcre2;
  };
  environment = {
    tools = [
      tools.perl
      tools.gnumake
      tools.sed
      tools.grep
      tools.gawk
      tools.diffutils
      tools.findutils
    ];
    libraries = [ final.pcre2 ];
  };
  runtime.shell = final.bash;
  runtime.tools = [
    final.coreutils
    tools.sed
    tools.grep
    tools.gawk
    tools.diffutils
    tools.findutils
  ];
  runtime.libraries = [ final.pcre2 ];

  installedInterface = {
    ordinaryControls = true;
    hasNls = true;
  };
  upstreamPlan = artifact: [
    {
      name = "gnugrep.restore-build-tree";
      tools = [ tools.python ];
      run = ''${tools.python}/bin/python3 -B ${../text-tool-restore.py} ${artifact}/${checkpoint} "$TVP_SOURCE_ROOT"'';
    }

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
    (command "prepare" ''
      ${tools.python}/bin/python3 -B ${../ordinary-text-source.py} ${final.bash}/bin/bash ${tools.perl}/bin/perl '${
        builtins.toJSON [
          "build-aux"
        ]
      }'
    '')
    (command "configure" ''
      export CONFIG_SHELL=${final.bash}/bin/bash SHELL=${final.bash}/bin/bash FORCE_UNSAFE_CONFIGURE=1
      ./configure --prefix="$out" ${lib.escapeShellArgs final.configureFlags} --enable-nls --enable-perl-regexp
      ${tools.grep}/bin/grep '^#define HAVE_LIBPCRE 1' config.h
      ${tools.grep}/bin/grep '^#define ENABLE_NLS 1' config.h
    '')
    (command "build" (productionMake "all"))
    (command "install" ''
      ${productionMake "install"}
      mkdir -p "$out/nix-support"
      cp "$TVP_SOURCE_ROOT/source-date-epoch" "$out/nix-support/source-date-epoch"
      cp config.h "$out/nix-support/config.h"
      ${tools.grep}/bin/grep -Ex 'gt_cv_func_gnugettext[0-9]+_libc=yes' config.log > "$out/nix-support/gettext-libc"
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
      tools = [
        tools.python
        tools.binutils
        tools.patchelf
      ];
      run = ''${tools.python}/bin/python3 -B ${../ordinary-text-output.py} "$out" "$TVP_ARTIFACT_ROOT" ${tools.patchelf}/bin/patchelf ${
        lib.escapeShellArg (
          builtins.toJSON {
            readelf = "${tools.binutils}/bin/readelf";
            shell = "${final.runtime.shell}/bin/bash";
            buildShell = "${final.bash}/bin/bash";
            paths = map (p: "${p}/bin") final.runtime.tools;
          }
        )
      }'';
    }
    (outputs.shebangs {
      paths = [ "bin" ];
      names = [
        "sh"
        "bash"
      ];
      interpreter = "${final.runtime.shell}/bin/bash";
    })
    (outputs.strip {
      flags = final.stripFlags;

      paths = [ "bin" ];
    })
    (rpaths {
      python = tools.python;
      binutils = tools.binutils;
      patchelf = tools.patchelf;
      base = final.base;
      libraries = final.runtime.libraries;
      dlopenDirectories = final.runtime.dlopenDirectories or [ ];
      paths = [ "bin" ];
    })
    (outputs.development {
      libraries = [ ];
    })
    ((import ../ordinary-text-check-paths.nix { inherit lib; }) {
      python = tools.python;
      binutils = tools.binutils;
      patchelf = tools.patchelf;
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
    platforms = lib.platforms.unix;
  };
}

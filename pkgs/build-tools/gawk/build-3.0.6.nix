# Gawk 3.0.6/3.1.8: pre-bignum, pre-Readline, GNU89; distinct archive/license profiles.
{
  tvp,
  lib,
  base,
  src,
  version,
  cStandard ? "gnu89",
  hardeningDisable ? [ "format" ],
  archiveExt ? "tar.bz2",
  license ? lib.licenses.gpl3Plus,
  doCheck ? true,
}:

final:
let
  context = tvp.builder.forBase final.base;
  inherit (context) steps outputs tools;

  checkpoint = "nix-support/gawk-build-tree";
  command =
    name: run:
    (final.base.environment final.environment)
    // {
      name = "gawk.${name}";
      cwd = "source";
      run = ''
        export NIX_HARDENING_ENABLE=${lib.escapeShellArg (lib.concatStringsSep " " (lib.subtractLists final.hardeningDisable final.base.compiler.defaultHardeningFlags))}
        ${run}
      '';
    };
in
{
  pname = "gawk";
  bash = tools.bash;
  inherit (tools) coreutils;
  inherit
    base
    src
    version
    cStandard
    hardeningDisable
    archiveExt
    license
    doCheck
    ;

  dependencyProviders = { };
  environment = {
    tools = with tools; [
      gnumake
      sed
      grep
      gawk
      diffutils
      findutils
    ];
    overrides.values.CFLAGS = "-O2 -std=${final.cStandard}";
  };
  runtime.libraries = [ ];
  runtime.shell = final.bash;
  runtime.tools = [
    final.coreutils
    tools.sed
    tools.grep
    tools.gawk
    tools.diffutils
    tools.findutils
  ];
  artifactName = "gawk-${final.version}"; # Equal-width compiled DEFPATH/LOCALEDIR slots.
  productionPlan = [
    (
      if final.archiveExt == "tar.gz" then
        steps.unpack {
          src = final.src;
          tar = tools.gnutar;
          inherit (tools) gzip findutils;
          compression = "gzip";
        }
      else
        {
          name = "source.unpack";
          tools = with tools; [
            gnutar
            bzip2
            findutils
          ];
          run = ''
            mkdir source
            PATH=${tools.bzip2}/bin:"$PATH" ${tools.gnutar}/bin/tar -xjf ${final.src} --strip-components=1 -C source
            chmod -R u+w source
            epoch=$(${tools.findutils}/bin/find source -type f -not -newer "$NIX_BUILD_TOP/.." -printf '%T@\n' | sort -n | tail -n1)
            epoch=''${epoch%%.*}
            if (( ''${epoch:-0} < 315532800 )); then epoch=315532800; fi
            printf '%s\n' "$epoch" > source-date-epoch
          '';
        }
    )
    (steps.prepareAutotools {
      name = "gawk.autotools";

      base = final.base;
    })
    (steps.shebangs {
      name = "gawk.source-shells";

      paths =
        [
          "configure"
          "install-sh"
          "mkinstalldirs"
          "missing"
          "awklib"
        ]
        ++ lib.optionals (final.version == "3.1.8") [
          "config.guess"
          "config.sub"
          "depcomp"
          "ylwrap"
        ];
      names = [
        "sh"
        "bash"
      ];
      interpreter = "${final.bash}/bin/bash";
    })
    (steps.shebangs {
      name = "gawk.source-perl";

      paths = [ "awklib" ];
      names = [ "perl" ];
      interpreter = "${tools.perl}/bin/perl";
    })
    (command "prepare" ''
      ${tools.python}/bin/python3 -B ${./ordinary/reserve-3.py} ${
        if final.version == "3.0.6" then "1" else "5"
      }
    '')
    (command "configure" ''
      export CONFIG_SHELL=${final.bash}/bin/bash SHELL=${final.bash}/bin/bash
      ./configure --prefix="$out"
    '')
    (command "build" ''${tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${final.bash}/bin/bash'')
    (command "install" ''
      ${tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${final.bash}/bin/bash install
      mkdir -p "$out/nix-support"
      cp "$TVP_SOURCE_ROOT/source-date-epoch" "$out/nix-support/source-date-epoch"
    '')
    {
      name = "gawk.save-build-tree";
      tools = [ tools.python ];
      run = ''${tools.python}/bin/python3 -B ${../../../lib/build-checkpoint.py} "$TVP_SOURCE_ROOT" "$out/${checkpoint}"'';
    }

  ];

  installedInterface = {
    ordinaryControls = false;
    hasNls = false;
  };
  upstreamPlan = artifact: [
    {
      name = "gawk.restore-build-tree";
      tools = [ tools.python ];
      run = ''${tools.python}/bin/python3 -B ${../text-tool-restore.py} ${artifact}/${checkpoint} "$TVP_SOURCE_ROOT"'';
    }

    {
      name = "gawk.upstream-frontends";
      tools = [
        tools.python
        tools.perl
      ];
      run = ''
        cd "$(cat "$TVP_SOURCE_ROOT/tree-path")"
        ${tools.python}/bin/python3 -B ${../ordinary-text-upstream-source.py} ${final.bash}/bin/bash ${tools.perl}/bin/perl '${builtins.toJSON [ "test" ]}'
      '';
    }
    {
      name = "gawk.upstream-shell";
      tools = [
        tools.python
        tools.gnumake
      ];
      env = (final.base.environment final.environment).env;
      run = ''
        cd "$(cat "$TVP_SOURCE_ROOT/tree-path")"
        ${tools.python}/bin/python3 -B ${./ordinary/reserve-3.py} ${
          if final.version == "3.0.6" then "1" else "5"
        } ${final.bash}/bin/bash
        export NIX_HARDENING_ENABLE=${lib.escapeShellArg (lib.concatStringsSep " " (lib.subtractLists final.hardeningDisable final.base.compiler.defaultHardeningFlags))}
        touch io.c
        ${tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${final.bash}/bin/bash
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
  plan = final.productionPlan ++ [
    (steps.split "gawk.finalize")
    (outputs.copyArtifacts { coreutils = final.coreutils; })
    {
      name = "gawk.drop-build-tree";
      tools = [ tools.coreutils ];
      run = ''${tools.coreutils}/bin/rm -rf -- "$out/${checkpoint}"'';
    }

    {
      name = "gawk.bind-paths";
      tools = [
        tools.python
        tools.binutils
      ];
      run = ''${tools.python}/bin/python3 -B ${./ordinary/finalize-3.py} "$out" "$TVP_ARTIFACT_ROOT" ${../../../lib/installed-tree.py} ${../../libraries/libxml2/ordinary/elf.py} ${tools.binutils}/bin/readelf ${final.runtime.shell}/bin/bash ${lib.escapeShellArg (lib.makeBinPath final.runtime.tools)}'';
    }
    (outputs.shebangs {
      paths = [ "bin" ];
      names = [
        "sh"
        "bash"
      ];
      interpreter = "${final.runtime.shell}/bin/bash";
    })
    (
      (outputs.shebangs {
        paths = [ "bin" ];
        names = [
          "awk"
          "gawk"
        ];
        selfInterpreter = "bin/gawk";
      })
      // {
        name = "output.awk-shebangs";
      }
    )
    (outputs.strip {
      paths = [ "bin" ];
    })
    (outputs.rpaths {
      base = final.base;
      libraries = final.runtime.libraries;
      dlopenDirectories = final.runtime.dlopenDirectories or [ ];
      paths = [ "bin" ];
    })
    (outputs.checkPaths {
      paths = [ "bin" ];
    })
  ];
  tvp.features.bignum = false;
  meta = {
    description = "GNU AWK";
    license = final.license;
    platforms = lib.platforms.unix;
  };
}

# Gawk 3.0.6/3.1.8: pre-bignum, pre-Readline, GNU89; distinct archive/license profiles.
{ tvp, lib, base, src, version, bash, coreutils, gnumake, gnutar,
  gzip, bzip2, python, binutils, patchelf, sed, grep, gawk, diffutils,
  findutils, perl, cStandard ? "gnu89", hardeningDisable ? [ "format" ],
  archiveExt ? "tar.bz2", license ? lib.licenses.gpl3Plus, doCheck ? true }:
final:
let
  inherit (tvp.builder) steps outputs;
  command = name: run: (final.base.environment final.environment) // {
    name = "gawk.${name}"; cwd = "source";
    run = ''
      export NIX_HARDENING_ENABLE=${lib.escapeShellArg (lib.concatStringsSep " " (lib.subtractLists final.hardeningDisable final.base.compiler.defaultHardeningFlags))}
      ${run}
    '';
  };
in {
  pname = "gawk";
  inherit base src version bash coreutils cStandard hardeningDisable archiveExt license doCheck;
  tools = { inherit gnumake gnutar gzip bzip2 python binutils patchelf sed grep gawk diffutils findutils perl; };
  dependencyProviders = final.tools;
  environment = {
    tools = with final.tools; [ gnumake sed grep gawk diffutils findutils ];
    overrides.values.CFLAGS = "-O2 -std=${final.cStandard}";
  };
  runtime.libraries = [ ];
  runtime.shell = final.bash;
  runtime.tools = [ final.coreutils final.tools.sed final.tools.grep final.tools.gawk final.tools.diffutils final.tools.findutils ];
  artifactName = "gawk-${final.version}"; # Equal-width compiled DEFPATH/LOCALEDIR slots.
  productionPlan = [
    (if final.archiveExt == "tar.gz" then steps.unpack {
      src = final.src; tar = final.tools.gnutar; inherit (final.tools) gzip findutils; compression = "gzip";
    } else {
      name = "source.unpack";
      tools = with final.tools; [ gnutar bzip2 findutils ];
      run = ''
        mkdir source
        PATH=${final.tools.bzip2}/bin:"$PATH" ${final.tools.gnutar}/bin/tar -xjf ${final.src} --strip-components=1 -C source
        chmod -R u+w source
        epoch=$(${final.tools.findutils}/bin/find source -type f -not -newer "$NIX_BUILD_TOP/.." -printf '%T@\n' | sort -n | tail -n1)
        epoch=''${epoch%%.*}
        if (( ''${epoch:-0} < 315532800 )); then epoch=315532800; fi
        printf '%s\n' "$epoch" > source-date-epoch
      '';
    })
    (steps.prepareAutotools { name = "gawk.autotools"; python = final.tools.python; bash = final.bash; base = final.base; })
    (steps.shebangs {
      name = "gawk.source-shells"; python = final.tools.python;
      paths = [ "configure" "install-sh" "mkinstalldirs" "missing" "test" "awklib" ]
        ++ lib.optionals (final.version == "3.1.8") [ "config.guess" "config.sub" "depcomp" "ylwrap" ];
      names = [ "sh" "bash" ]; interpreter = "${final.bash}/bin/bash";
    })
    (steps.shebangs {
      name = "gawk.source-perl"; python = final.tools.python;
      paths = [ "test" "awklib" ]; names = [ "perl" ]; interpreter = "${final.tools.perl}/bin/perl";
    })
    (command "prepare" ''
      ${final.tools.python}/bin/python3 -B ${./reserve-3.py} ${if final.version == "3.0.6" then "1" else "5"}
    '')
    (command "configure" ''
      export CONFIG_SHELL=${final.bash}/bin/bash SHELL=${final.bash}/bin/bash
      ./configure --prefix="$out"
    '')
    (command "build" ''${final.tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${final.bash}/bin/bash'')
    (command "install" ''
      ${final.tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${final.bash}/bin/bash install
      mkdir -p "$out/nix-support"
      cp "$TVP_SOURCE_ROOT/source-date-epoch" "$out/nix-support/source-date-epoch"
    '')
  ];
  testShell = final.bash;
  upstreamPlan = steps.insertAfter "gawk.prepare" [
    (command "test-shell" ''
      ${final.tools.python}/bin/python3 -B ${./reserve-3.py} ${if final.version == "3.0.6" then "1" else "5"} ${final.testShell}/bin/bash
    '')
  ] (builtins.filter (step: step.name != "gawk.install") final.productionPlan);
  upstreamCheck = (command "check" ''${final.tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${final.bash}/bin/bash check'') // { enabled = final.doCheck; };
  plan = final.productionPlan ++ [
    (steps.split "gawk.finalize")
    (outputs.copyArtifacts { coreutils = final.coreutils; })
    {
      name = "gawk.bind-paths"; tools = [ final.tools.python final.tools.binutils ];
      run = ''${final.tools.python}/bin/python3 -B ${./finalize-3.py} "$out" "$TVP_ARTIFACT_ROOT" ${../../../../lib/installed-tree.py} ${../../../libraries/libxml2/ordinary/elf.py} ${final.tools.binutils}/bin/readelf ${final.runtime.shell}/bin/bash ${lib.escapeShellArg (lib.makeBinPath final.runtime.tools)}'';
    }
    (outputs.shebangs { python = final.tools.python; paths = [ "bin" ]; names = [ "sh" "bash" ]; interpreter = "${final.runtime.shell}/bin/bash"; })
    ((outputs.shebangs { python = final.tools.python; paths = [ "bin" ]; names = [ "awk" "gawk" ]; selfInterpreter = "bin/gawk"; }) // { name = "output.awk-shebangs"; })
    (outputs.strip { inherit (final.tools) python binutils; paths = [ "bin" ]; })
    (outputs.rpaths { inherit (final.tools) python binutils patchelf; base = final.base; libraries = final.runtime.libraries; dlopenDirectories = final.runtime.dlopenDirectories or [ ]; paths = [ "bin" ]; })
    (outputs.checkPaths { inherit (final.tools) python binutils patchelf; paths = [ "bin" ]; })
  ];
  tvp.features.bignum = false;
  meta = { description = "GNU AWK"; license = final.license; platforms = lib.platforms.unix; };
}

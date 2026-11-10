# Gzip 1.13–1.14 share the installed helper layout and gzexe embedded-script skip count.
# Complete ordinary procedure; latest and frozen construction remain independently selected.
{
  tvp,
  lib,
  base,
  src,
  version,
  bash,
  coreutils,
  gnumake,
  gnutar,
  xz,
  findutils,
  sed,
  grep,
  gawk,
  diffutils,
  pager,
  python,
  binutils,
  patchelf,
  configureFlags ? [ ],
}:
final:
let
  inherit (tvp.builder) steps outputs;
  command =
    name: run:
    (final.base.environment final.environment)
    // {
      name = "gzip.${name}";
      cwd = "source";
      inherit run;
    };
  make = ''${final.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${final.bash}/bin/bash'';
in
{
  pname = "gzip";
  inherit
    base
    src
    version
    bash
    coreutils
    ;
  inherit
    gnumake
    gnutar
    xz
    findutils
    sed
    grep
    gawk
    diffutils
    pager
    python
    binutils
    patchelf
    configureFlags
    ;
  dependencyProviders = {
    bash = final.bash;
    coreutils = final.coreutils;
    gnumake = final.gnumake;
    gnutar = final.gnutar;
    xz = final.xz;
    findutils = final.findutils;
    sed = final.sed;
    grep = final.grep;
    gawk = final.gawk;
    diffutils = final.diffutils;
    pager = final.pager;
    python = final.python;
    binutils = final.binutils;
    patchelf = final.patchelf;
  };
  environment = {
    tools = [
      final.gnumake
      final.findutils
      final.sed
      final.grep
      final.gawk
      final.diffutils
      final.pager
    ];
    libraries = [ ];
  };
  runtime.libraries = [ ];
  plan = steps.sequence [
    (steps.unpack {
      src = final.src;
      tar = final.gnutar;
      xz = final.xz;
      findutils = final.findutils;
    })
    (steps.prepareAutotools {
      name = "gzip.prepare";
      bash = final.bash;
      python = final.python;
      base = final.base;
    })
    (command "configure" ''
      export CONFIG_SHELL=${final.bash}/bin/bash SHELL=${final.bash}/bin/bash
      ./configure --prefix="$out" GREP=${final.grep}/bin/grep ${lib.escapeShellArgs final.configureFlags}
    '')
    (command "build" make)
    (command "install" ''
      ${make} install
      mkdir -p "$out/nix-support"
      cp "$TVP_SOURCE_ROOT/source-date-epoch" "$out/nix-support/source-date-epoch"
    '')
    (steps.split "gzip.finalize")
    (outputs.copyArtifacts { coreutils = final.coreutils; })
    {
      name = "gzip.relocate";
      tools = [ final.python ];
      run = ''
        ${final.python}/bin/python3 -B ${./relocate.py} "$out" "$TVP_ARTIFACT_ROOT" "${final.patchelf}/bin/patchelf"
      '';
    }
    {
      name = "gzip.bind-helpers";
      tools = [ final.python ];
      run = ''
        ${final.python}/bin/python3 -B - "$out" <<'PY'
        import sys
        from pathlib import Path
        root = Path(sys.argv[1])
        # Every helper executes in a declared utility profile. Preserve user PATH
        # after that profile and preserve explicit GREP/CMP/DIFF/PAGER overrides.
        path = f"{root}/bin:${final.coreutils}/bin:${final.sed}/bin:${final.grep}/bin:${final.diffutils}/bin:${final.pager}/bin:${final.bash}/bin"
        for name in ['gunzip','zcat','gzexe','zcmp','zdiff','zegrep','zfgrep','zforce','zgrep','zless','zmore','znew','uncompress']:
            p = root / 'bin' / name
            text = p.read_text()
            lines = text.splitlines(keepends=True)
            assert lines[0].startswith('#!'), name
            # gzexe emits a second script. Its fixed skip count includes that
            # script's new PATH line; the generated executable keeps its tools.
            if name == 'gzexe':
                assert text.count('skip=49\n') == 1
                text = text.replace('skip=49\n','skip=50\n')
            rendered=[]
            for line in text.splitlines(keepends=True):
                if line.startswith('#!'):
                    rendered.append('#!${final.bash}/bin/bash\n')
                    if len(rendered) == 1:
                        rendered.append(f'PATH={path}:"$PATH"; export PATH\n')
                else:
                    rendered.append(line)
                    if name == 'gzexe' and line == 'skip=50\n':
                        rendered.append(f'PATH={path}:"$PATH"; export PATH\n')
            text = "".join(rendered)
            if name == 'zless':
                text = text.replace('exec less ', 'SHELL=${final.bash}/bin/bash; export SHELL\nexec less ')
            if name == 'zmore':
                assert text.count('$'+'{PAGER-more}') == 1
                text = text.replace('$'+'{PAGER-more}', '$'+'{PAGER-${final.pager}/bin/less}')
            p.write_text(text)
        PY
      '';
    }
    (outputs.strip {
      python = final.python;
      binutils = final.binutils;
      paths = [ "bin" ];
    })
    (outputs.rpaths {
      python = final.python;
      binutils = final.binutils;
      patchelf = final.patchelf;
      base = final.base;
      libraries = final.runtime.libraries;
      dlopenDirectories = final.runtime.dlopenDirectories or [ ];
      paths = [ "bin" ];
    })
    (outputs.development {
      python = final.python;
      libraries = [ ];
    })
    (outputs.checkPaths {
      python = final.python;
      binutils = final.binutils;
      patchelf = final.patchelf;
      paths = [ "bin" ];
    })
  ];
  meta = {
    description = "GNU gzip compression utilities";
    homepage = "https://www.gnu.org/software/gzip/";
    license = lib.licenses.gpl3Plus;
    platforms = lib.platforms.unix;
    mainProgram = "gzip";
  };
}

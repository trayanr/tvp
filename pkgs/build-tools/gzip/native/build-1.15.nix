# Ordinary 1.15 onward: explicit native steps and the complete installed helper
# profile. Earlier releases and frozen construction keep build-1.13.nix.
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
  make = ''${gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${final.bash}/bin/bash'';
in
{
  pname = "gzip";
  # Equal-width compiled-prefix ABI; the artifact remains a distinct producer.
  artifactName = "${final.pname}-${final.version}";
  inherit
    base
    src
    version
    bash
    coreutils
    ;
  environment = {
    tools = [
      gnumake
      findutils
      sed
      grep
      gawk
      diffutils
      pager
    ];
    libraries = [ ];
  };
  runtime.libraries = [ ];
  plan = steps.sequence [
    (steps.unpack {
      src = final.src;
      tar = gnutar;
      inherit xz findutils;
    })
    (steps.prepareAutotools {
      name = "gzip.prepare";
      bash = final.bash;
      inherit python;
      base = final.base;
    })
    (command "configure" ''
      export CONFIG_SHELL=${final.bash}/bin/bash SHELL=${final.bash}/bin/bash
      ./configure --prefix="$out" GREP=${grep}/bin/grep ${lib.escapeShellArgs configureFlags}
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
      tools = [ python ];
      run = ''${python}/bin/python3 -B ${../../owned-split-output.py} "$out" "$TVP_ARTIFACT_ROOT" ${
        lib.escapeShellArg (
          builtins.toJSON {
            text = [ ];
            slots = [ ];
            fixed = [ ];
          }
        )
      } ${../../../../lib/installed-tree.py}'';
    }
    {
      name = "gzip.bind-helpers";
      tools = [ python ];
      run = ''
        ${python}/bin/python3 -B - "$out" <<'PY'
        import sys
        from pathlib import Path
        root = Path(sys.argv[1])
        # Every helper executes in a declared utility profile. Preserve user PATH
        # after that profile and preserve explicit GREP/CMP/DIFF/PAGER overrides.
        path = f"{root}/bin:${coreutils}/bin:${sed}/bin:${grep}/bin:${diffutils}/bin:${pager}/bin:${final.bash}/bin"
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
                text = text.replace('$'+'{PAGER-more}', '$'+'{PAGER-${pager}/bin/less}')
            p.write_text(text)
        PY
      '';
    }
    (outputs.strip {
      inherit python binutils;
      paths = [ "bin" ];
    })
    (outputs.rpaths {
      inherit python binutils patchelf;
      base = final.base;
      libraries = final.runtime.libraries;
      dlopenDirectories = final.runtime.dlopenDirectories or [ ];
      paths = [ "bin" ];
    })
    (outputs.development {
      inherit python;
      libraries = [ ];
    })
    (outputs.checkPaths {
      inherit python binutils patchelf;
      paths = [ "bin" ];
    })
  ];
  meta = {
    description = "GNU gzip compression utilities";
    homepage = "https://www.gnu.org/software/gzip/";
    license = lib.licenses.gpl3Plus;
    platforms = [ "x86_64-linux" ];
    mainProgram = "gzip";
  };
}

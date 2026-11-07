# Native ordinary 10.49 boundary: complete source-GNU procedure for 10.49 only.
# Earlier releases and captured construction generations retain independent routes.
{
  tvp,
  lib,
  base,
  src,
  version,
  bash,
  coreutils,
  pkgConfig,
  gnumake,
  gnutar,
  python,
  binutils,
  patchelf,
  sed,
  grep,
  gawk,
  diffutils,
  findutils,
  bzip2,
  perl,
  doCheck ? true,
  static ? false,
}:
final:
let
  inherit (tvp.builder) steps outputs;
  command =
    name: run:
    (final.base.environment final.environment)
    // {
      name = "pcre2.${name}";
      cwd = "source";
      inherit run;
    };
in
{
  pname = "pcre2";
  inherit
    base
    src
    version
    bash
    coreutils
    ;
  environment = {
    tools = [
      pkgConfig
      gnumake
      sed
      grep
      gawk
      diffutils
      findutils
      perl
    ];
    libraries = [ ];
  };
  runtime.libraries = [ ];
  plan = steps.sequence [
    {
      name = "source.unpack";
      tools = [
        gnutar
        bzip2
        findutils
      ];
      run = ''
        mkdir source
        ${bzip2}/bin/bzip2 -dc ${final.src} | ${gnutar}/bin/tar -xf - --strip-components=1 -C source
        chmod -R u+w source
        epoch=$(${findutils}/bin/find source -type f -not -newer "$NIX_BUILD_TOP/.." -printf '%T@\n' | sort -n | tail -n1)
        epoch=''${epoch%%.*}
        if (( ''${epoch:-0} < 315532800 )); then epoch=315532800; fi
        printf '%s\n' "$epoch" > source-date-epoch
      '';
    }
    (steps.prepareAutotools {
      name = "pcre2.prepare";
      bash = final.bash;
      inherit python;
      base = final.base;
    })
    {
      name = "pcre2.callout-echo";
      cwd = "source";
      tools = [
        python
        coreutils
      ];
      run = ''
        # Upstream's four pcre2grep callouts execute /bin/echo, absent in the
        # sandbox. Bind those exact commands to the declared executable.
        ${python}/bin/python3 -B - ${coreutils}/bin/echo <<'PYTHON'
        from pathlib import Path
        import os, sys
        p = Path('RunGrepTest'); info = p.stat(); data = p.read_bytes()
        assert data.count(b'/bin/echo|') == 4
        p.write_bytes(data.replace(b'/bin/echo|', os.fsencode(sys.argv[1]) + b'|'))
        os.utime(p, ns=(info.st_atime_ns, info.st_mtime_ns))
        PYTHON
      '';
    }
    (steps.shebangs {
      name = "pcre2.source-shells";
      inherit python;
      paths = [
        "RunTest"
        "RunGrepTest"
        "test-driver"
        "compile"
        "config.guess"
        "config.sub"
        "install-sh"
        "missing"
        "depcomp"
        "ar-lib"
      ];
      names = [
        "sh"
        "bash"
      ];
      interpreter = "${final.bash}/bin/bash";
    })
    (command "configure" ''
      export CONFIG_SHELL=${final.bash}/bin/bash SHELL=${final.bash}/bin/bash FORCE_UNSAFE_CONFIGURE=1
      ./configure --prefix="$out" --enable-pcre2-16 --enable-pcre2-32 --enable-jit --enable-unicode --enable-shared ${
        if static then "--enable-static" else "--disable-static"
      }
    '')
    (command "build" ''${gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${final.bash}/bin/bash'')
    (
      (command "check" ''${gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${final.bash}/bin/bash check'')
      // {
        enabled = doCheck;
      }
    )
    (command "install" ''
      ${gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${final.bash}/bin/bash install
      mkdir -p "$out/nix-support"
      cp "$TVP_SOURCE_ROOT/source-date-epoch" "$out/nix-support/source-date-epoch"
    '')
    {
      name = "pcre2.self-rpaths";
      tools = [
        python
        patchelf
      ];
      run = ''
        ${python}/bin/python3 -B - "$out" ${patchelf}/bin/patchelf <<'PYTHON'
        from pathlib import Path
        import subprocess, sys
        root = Path(sys.argv[1])
        for directory in ['bin', 'lib']:
            for p in sorted((root/directory).iterdir()):
                if p.is_symlink() or not p.is_file(): continue
                with p.open('rb') as f: magic=f.read(4)
                if magic == b'\x7fELF':
                    subprocess.run([sys.argv[2], '--add-rpath', str(root/'lib'), str(p)], check=True)
        PYTHON
      '';
    }
    (outputs.shebangs {
      inherit python;
      paths = [
        "bin"
        "lib"
      ];
      names = [
        "sh"
        "bash"
      ];
      interpreter = "${final.bash}/bin/bash";
    })
    (outputs.strip {
      inherit python binutils;
      paths = [
        "bin"
        "lib"
      ];
    })
    (outputs.stripArchives {
      inherit python binutils;
      paths = [ "lib" ];
    })
    (outputs.rpaths {
      inherit python binutils patchelf;
      base = final.base;
      libraries = final.runtime.libraries;
      dlopenDirectories = final.runtime.dlopenDirectories or [ ];
      paths = [
        "bin"
        "lib"
      ];
    })
    (outputs.development {
      inherit python;
      libraries = [ ];
    })
    (outputs.checkPaths {
      inherit python binutils patchelf;
      paths = [
        "bin"
        "lib"
      ];
    })
  ];
  tvp.features = {
    shared = true;
    inherit static;
    jit = true;
    unicode = true;
  };
  meta = {
    description = "Perl-compatible regular expressions library";
    license = lib.licenses.bsd3;
    platforms = [ "x86_64-linux" ];
  };
}

# Native ordinary 6.6 boundary: complete source-GNU procedure for 6.6 only.
# Earlier releases and captured construction generations retain independent routes.
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
  python,
  binutils,
  patchelf,
  sed,
  grep,
  gawk,
  diffutils,
  findutils,
  gzip,
  pkgConfig,
  doCheck ? true,
}:
final:
let
  inherit (tvp.builder) steps outputs;
  command =
    name: run:
    (final.base.environment final.environment)
    // {
      name = "ncurses.${name}";
      cwd = "source";
      inherit run;
    };
in
{
  pname = "ncurses";
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
      sed
      grep
      gawk
      diffutils
      findutils
      pkgConfig
    ];
    libraries = [ ];
  };
  runtime.libraries = [ ];
  development.includeDirectories = [
    "include/ncursesw"
    "include"
  ];
  plan = steps.sequence [
    (steps.unpack {
      src = final.src;
      tar = gnutar;
      inherit gzip findutils;
      compression = "gzip";
    })
    (steps.prepareAutotools {
      name = "ncurses.prepare";
      bash = final.bash;
      inherit python;
      base = final.base;
    })
    (steps.shebangs {
      name = "ncurses.source-shells";
      inherit python;
      paths = [
        "misc"
        "progs"
        "mk-1st.awk"
      ];
      names = [
        "sh"
        "bash"
      ];
      interpreter = "${final.bash}/bin/bash";
    })
    (command "configure" ''
      export CONFIG_SHELL=${final.bash}/bin/bash SHELL=${final.bash}/bin/bash FORCE_UNSAFE_CONFIGURE=1
      mkdir -p "$out/lib/pkgconfig"
      ./configure --prefix="$out" --with-shared --enable-widec --without-debug --enable-pc-files --with-pkg-config-libdir="$out/lib/pkgconfig" --with-pkg-config=${pkgConfig}/bin/pkg-config
    '')
    (command "build" ''${gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${final.bash}/bin/bash'')
    # Upstream supplies interactive test programs; installed C/C++/database
    # consumers are exercised by the ordinary suite instead of a make check target.
    (command "install" ''
      ${gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${final.bash}/bin/bash install
      mkdir -p "$out/nix-support"
      cp "$TVP_SOURCE_ROOT/source-date-epoch" "$out/nix-support/source-date-epoch"
    '')
    {
      name = "ncurses.self-rpaths";
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
    userData = true;
    widec = true;
    cxx = true;
    pkgConfig = true;
    libName = "ncursesw";
    shared = true;
    static = true;
  };
  meta = {
    description = "Free software emulation of curses";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
  };
}

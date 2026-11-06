# Selected source-native release; canonical family construction is unchanged.
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
  gzip,
  python,
  binutils,
  patchelf,
  pkgConfig,
  cStandard ? null,
  cxxStandard ? null,
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
      run = run;
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
      pkgConfig
    ];
    libraries = [ ];
  };
  runtime.libraries = [ ];
  plan = steps.sequence [
    (steps.unpack {
      inherit src gzip;
      tar = gnutar;
      compression = "gzip";
    })
    (steps.prepareAutotools {
      name = "ncurses.prepare";
      inherit bash python;
      base = final.base;
    })

    (command "configure" ''
      export CONFIG_SHELL=${bash}/bin/bash SHELL=${bash}/bin/bash
      mkdir -p "$out/lib/pkgconfig"
      ${lib.optionalString (cStandard != null) ''export CFLAGS="''${CFLAGS:--O2} -std=${cStandard}"''}
      ${lib.optionalString (
        cxxStandard != null
      ) ''export CXXFLAGS="''${CXXFLAGS:--O2} -std=${cxxStandard}"''}
      ./configure --prefix="$out" --with-shared --enable-widec --without-debug \
        --enable-pc-files --with-pkg-config-libdir="$out/lib/pkgconfig" \
        --with-pkg-config=${pkgConfig}/bin/pkg-config
    '')
    (command "build" ''${gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${bash}/bin/bash'')
    # ncurses provides test programs, not an automated make check target.
    # Installed noninteractive C/C++/terminfo checks live in the composition suite.
    (command "install" ''
      ${gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${bash}/bin/bash install
      mkdir -p "$out/nix-support"
      cp "$TVP_SOURCE_ROOT/source-date-epoch" "$out/nix-support/source-date-epoch"
    '')

    (outputs.strip {
      inherit python binutils;
      paths = [
        "lib"
        "bin"
      ];
    })
    (outputs.stripArchives {
      inherit python binutils;
      paths = [ "lib" ];
    })
    {
      name = "ncurses.self-rpaths";
      tools = [
        python
        patchelf
      ];
      run = ''
        # Installed tools and add-on DSOs use this output's wide library.
        # Supply self paths before the shared helper prunes external providers.
        ${python}/bin/python3 -B - "$out" ${patchelf}/bin/patchelf <<'PYTHON'
        from pathlib import Path
        import subprocess, sys
        root=Path(sys.argv[1])
        for directory in ['bin', 'lib']:
            for p in sorted((root/directory).iterdir()):
                if p.is_symlink() or not p.is_file(): continue
                with p.open('rb') as f: magic=f.read(4)
                if magic == b'\x7fELF':
                    subprocess.run([sys.argv[2], '--add-rpath', str(root/'lib'), str(p)], check=True)
        PYTHON
      '';
    }
    (outputs.rpaths {
      inherit python binutils patchelf;
      base = final.base;
      libraries = final.runtime.libraries;
      paths = [
        "lib"
        "bin"
      ];
    })
    (outputs.development {
      inherit python;
      libraries = [ ];
    })
    (outputs.checkPaths {
      inherit python binutils patchelf;
      paths = [
        "lib"
        "bin"
      ];
    })
  ];
  tvp.features = {
    shared = true;
    static = true;
    widec = true;
    cxx = true;
    pkgConfig = true;
    inherit cStandard cxxStandard;
  };
  meta.platforms = [ "x86_64-linux" ];
}

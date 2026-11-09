# Ordinary native 2.18.3 only; retained construction and historical profiles use independent recipes.
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
  xz,
  meson,
  ninja,
  gperf,
  pkgConfig,
  freetype,
  expat,
}:
final:
let
  inherit (tvp.builder) steps outputs;
  command =
    name: run:
    (final.base.environment final.environment)
    // {
      name = "fontconfig.${name}";
      cwd = "source";
      run = ''
          mkdir -p "$evidence"
          status=0
        export TVP_SOURCE_ROOT
          ${final.bash}/bin/bash -euo pipefail -c ${lib.escapeShellArg run} > "$evidence/${name}.log" 2>&1 || status=$?
          cat "$evidence/${name}.log"
          printf '%s\n' "$status" > "$evidence/${name}.status"
          test "$status" = 0
      '';
    };
  make = ''${final.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${final.bash}/bin/bash'';
in
{
  pname = "fontconfig";
  inherit
    base
    src
    version
    bash
    coreutils
    gnumake
    gnutar
    python
    binutils
    patchelf
    sed
    grep
    gawk
    diffutils
    findutils
    xz
    meson
    ninja
    gperf
    pkgConfig
    freetype
    expat
    ;
  outputs = [
    "out"
    "evidence"
  ];
  environment = {
    tools = [
      final.gnumake
      final.python
      final.sed
      final.grep
      final.gawk
      final.diffutils
      final.findutils
      final.xz
      final.meson
      final.ninja
      final.gperf
      final.pkgConfig
    ];
    libraries = [
      final.freetype
      final.expat
    ];
  };
  runtime.libraries = [
    final.freetype
    final.expat
  ];
  plan = steps.sequence [
    (steps.unpack {
      src = final.src;
      tar = final.gnutar;
      xz = final.xz;
      findutils = final.findutils;
      compression = "xz";
    })
    (steps.shebangs {
      name = "fontconfig.prepare-python";
      python = final.python;
      interpreter = "${final.python}/bin/python3";
      names = [ "python3" ];
      paths = [
        "src/cutout.py"
        "conf.d/link_confs.py"
        "conf.d/write-35-lang-normalize-conf.py"
        "fc-case/fc-case.py"
        "fc-const/fc-const.py"
        "fc-genericfamily/fc-genericfamily.py"
        "fc-lang/fc-lang.py"
      ];
    })
    (command "configure" ''
      export NINJA=${final.ninja}/bin/ninja
      ${final.meson}/bin/meson setup build . --prefix="$out" --libdir=lib --buildtype=release --wrap-mode=nodownload -Dauto_features=enabled \
        -Ddoc=disabled -Dnls=disabled -Dtests=enabled -Dtests-bwrap=disabled \
        -Dtests-external-fonts=disabled -Dtools=enabled -Dcache-build=disabled \
        -Dxml-backend=expat -Dfontations=disabled
    '')
    (command "build" ''${final.meson}/bin/meson compile -C build -j "$NIX_BUILD_CORES"'')
    (command "check" ''
      status=0
      export TVP_SOURCE_ROOT
      ${final.meson}/bin/meson test -C build --print-errorlogs || status=$?
      cp -r build/meson-logs "$evidence/meson-logs"
      exit "$status"
    '')
    (command "install" "${final.meson}/bin/meson install -C build --no-rebuild")
    {
      name = "fontconfig.self-rpaths";
      tools = [ final.patchelf ];
      run = ''
        for program in "$out"/bin/fc-*; do
          ${final.patchelf}/bin/patchelf --add-rpath "$out/lib" "$program"
        done
      '';
    }
    {
      name = "fontconfig.config-links";
      tools = [ final.python ];
      run = ''${final.python}/bin/python3 -B ${../check-config-links.py} "$out"'';
    }
    (command "receipt" ''
      mkdir -p "$out/nix-support"
      cp "$TVP_SOURCE_ROOT/source-date-epoch" "$out/nix-support/source-date-epoch"
    '')
    (outputs.strip {
      python = final.python;
      binutils = final.binutils;
      paths = [
        "bin"
        "lib"
      ];
    })
    (outputs.rpaths {
      python = final.python;
      binutils = final.binutils;
      patchelf = final.patchelf;
      base = final.base;
      libraries = final.runtime.libraries;
      paths = [
        "bin"
        "lib"
      ];
    })
    (outputs.development {
      python = final.python;
      libraries = [
        final.freetype
        final.expat
      ];
    })
    (outputs.checkPaths {
      python = final.python;
      binutils = final.binutils;
      patchelf = final.patchelf;
      paths = [
        "bin"
        "lib"
      ];
    })
  ];
  tvp.features = {
    tests = true;
    tools = true;
    doc = false;
    nls = false;
    tests-bwrap = false;
    tests-external-fonts = false;
    cache-build = false;
    xml-backend = "expat";
    fontations = false;
  };
  meta = {
    description = "Font discovery and configuration library";
    homepage = "https://fontconfig.org/";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
  };
}

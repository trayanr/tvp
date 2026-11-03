# Linux embeds config/template/cache paths in the library. This recipe has no
# split: runtime edits rebuild Fontconfig, preserving its compiled self paths.
{
  tvp,
  lib,
  base,
  src,
  version,
  bash,
  coreutils,
  gnutar,
  xz,
  meson,
  ninja,
  python,
  pkg-config,
  gperf,
  freetype,
  expat,
  binutils,
  patchelf,
  doCheck ? true,
}:
let
  inherit (tvp.builder) steps outputs;
  elfPaths = [
    "bin"
    "lib"
  ];
in
final:
let
  environment = final.base.environment final.environment;
  command =
    name: cwd: run:
    environment
    // {
      inherit name cwd run;
      env = environment.env // {
        NINJA = "${ninja}/bin/ninja";
      };
    };
in
{
  pname = "fontconfig";
  inherit
    base
    src
    version
    bash
    coreutils
    ;
  environment = {
    tools = [
      meson
      ninja
      python
      pkg-config
      gperf
    ];
    libraries = [
      freetype
      expat
    ];
  };
  runtime.libraries = [
    freetype
    expat
  ];
  plan = steps.sequence [
    (steps.unpack {
      inherit src xz;
      tar = gnutar;
    })
    (steps.shebangs {
      name = "fontconfig.prepare-python";
      inherit python;
      interpreter = "${python}/bin/python3";
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
    (command "fontconfig.configure" "source" ''
      ${meson}/bin/meson setup build . --prefix="$out" --libdir=lib --buildtype=release --wrap-mode=nodownload -Dauto_features=enabled \
        -Ddoc=disabled -Dnls=disabled -Dtests=enabled -Dtests-bwrap=disabled \
        -Dtests-external-fonts=disabled -Dtools=enabled -Dcache-build=disabled \
        -Dxml-backend=expat -Dfontations=disabled
    '')
    (command "fontconfig.build" "source/build" ''${meson}/bin/meson compile -j "$NIX_BUILD_CORES"'')
    (
      (command "fontconfig.check" "source/build" ''${meson}/bin/meson test --print-errorlogs'')
      // {
        enabled = doCheck;
      }
    )
    (command "fontconfig.install" "source/build" ''
      ${meson}/bin/meson install --no-rebuild
      mkdir -p "$out/nix-support"
      cp "$TVP_SOURCE_ROOT/source-date-epoch" "$out/nix-support/source-date-epoch"
    '')
    (outputs.strip {
      inherit python binutils;
      paths = elfPaths;
    })
    {
      # Meson removes its build-tree RUNPATH on install. Declare the installed
      # CLI-to-library directory before authoritative lookup pruning/checks.
      name = "fontconfig.self-rpaths";
      tools = [ patchelf ];
      run = ''
        for program in "$out"/bin/fc-*; do
          ${patchelf}/bin/patchelf --add-rpath "$out/lib" "$program"
        done
      '';
    }
    (outputs.rpaths {
      inherit python binutils patchelf;
      base = final.base;
      paths = elfPaths;
      libraries = final.runtime.libraries;
    })
    # fcfreetype.h includes ft2build.h; fontconfig.pc Requires.private
    # freetype2 and expat. Keep this separate from runtime lookup selection.
    (outputs.development {
      inherit python;
      libraries = [
        freetype
        expat
      ];
    })
    (outputs.checkSymlinks {
      inherit python;
      paths = [
        "lib/libfontconfig.so"
        "lib/libfontconfig.so.1"
      ];
    })
    {
      name = "fontconfig.config-links";
      tools = [ python ];
      run = "${python}/bin/python3 -B ${./check-config-links.py} \"$out\"";
    }
    (outputs.checkPaths {
      inherit python binutils patchelf;
      paths = elfPaths;
    })
  ];
  tvp.features = {
    inherit doCheck;
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

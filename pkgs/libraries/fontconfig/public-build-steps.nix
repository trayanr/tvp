# Independent public tests-enabled build-steps profile. Private injected evidence
# and named-step consumers retain build-steps-2.18.3.nix byte for byte.
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
  pkg-config,
  freetype,
  expat,
  doCheck ? true,
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
      inherit run;
    };
  make = ''${final.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${final.bash}/bin/bash'';
in
{
  pname = "fontconfig";
  artifactName = "${final.pname}-${final.version}";
  inherit
    base
    src
    version
    doCheck
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
    pkg-config
    freetype
    expat
    ;
  outputs = [ "out" ];
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
      final.pkg-config
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
    # This public profile compiles upstream test programs as a production checkpoint.
    # Execution and acceptance are independent U products. cache-build stays disabled:
    # no generated cache payload needs rehashing after rebasing config/cache roots.
    (command "configure" ''
      export NINJA=${final.ninja}/bin/ninja
      ${final.meson}/bin/meson setup build . --prefix="$out" --libdir=lib --buildtype=release --wrap-mode=nodownload -Dauto_features=enabled \
        -Ddoc=disabled -Dnls=disabled -Dtests=enabled -Dtests-bwrap=disabled \
        -Dtests-external-fonts=disabled -Dtools=enabled -Dcache-build=disabled \
        -Dxml-backend=expat -Dfontations=disabled
    '')
    (command "build" ''${final.meson}/bin/meson compile -C build -j "$NIX_BUILD_CORES"'')
    (command "install" "${final.meson}/bin/meson install -C build --no-rebuild")
    (command "receipt" ''
      mkdir -p "$out/nix-support"
      cp "$TVP_SOURCE_ROOT/source-date-epoch" "$out/nix-support/source-date-epoch"
    '')
    (steps.split "fontconfig.finalize")
    (tvp.builder.outputs.copyArtifacts {
      coreutils = final.coreutils;
    })
    {
      name = "fontconfig.relocate";
      tools = [ final.python ];
      run = ''${final.python}/bin/python3 -B ${./profile-relocate.py} "$out" "$TVP_ARTIFACT_ROOT" ${final.binutils}/bin/readelf ${final.patchelf}/bin/patchelf ${../libxml2/ordinary/elf.py} ${final.binutils}/bin/objdump'';
    }
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
      run = ''${final.python}/bin/python3 -B ${./check-config-links.py} "$out"'';
    }
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
    doCheck = final.doCheck;
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

# Complete fontconfig 2.18.3 procedure; earlier providers stay explicit.
{
  tvp,
  lib,
  base,
  src,
  version,
  expat,
  freetype,
  gperf,
  meson,
  ninja,
  pkg-config,
  doCheck ? true,
}:
final:
let
  context = tvp.builder.forBase final.base;
  inherit (context) steps outputs tools;
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
  make = ''${tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${final.bash}/bin/bash'';
in
{
  pname = "fontconfig";
  artifactName = "${final.pname}-${final.version}";
  inherit
    base
    src
    version
    doCheck
    meson
    ninja
    gperf
    pkg-config
    freetype
    expat
    ;
  inherit (tools) bash coreutils;
  outputs = [
    "out"
    "evidence"
  ];
  environment = {
    tools = [
      tools.gnumake
      tools.python
      tools.sed
      tools.grep
      tools.gawk
      tools.diffutils
      tools.findutils
      tools.xz
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
      compression = "xz";
    })
    (steps.shebangs {
      name = "fontconfig.prepare-python";
      interpreter = "${tools.python}/bin/python3";
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
    # Test binaries are private validation work. cache-build stays disabled:
    # no generated cache payload needs rehashing after rebasing config/cache roots.
    (command "configure" ''
      export NINJA=${final.ninja}/bin/ninja
      ${final.meson}/bin/meson setup build . --prefix="$out" --libdir=lib --buildtype=release --wrap-mode=nodownload -Dauto_features=enabled \
        -Ddoc=disabled -Dnls=disabled -Dtests=disabled -Dtests-bwrap=disabled \
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
    (outputs.copyArtifacts {
      outputs = final.outputs;
    })
    {
      name = "fontconfig.relocate";
      tools = [ tools.python ];
      run = ''${tools.python}/bin/python3 -B ${../jdk-support-relocate.py} "$out" "$TVP_ARTIFACT_ROOT" ${
        if builtins.elem "evidence" final.outputs then
          ''"$evidence" "''${TVP_ARTIFACT_OUTPUTS[evidence]}"''
        else
          ""
      }'';
    }
    {
      name = "fontconfig.self-rpaths";
      tools = [ tools.patchelf ];
      run = ''
        for program in "$out"/bin/fc-*; do
          ${tools.patchelf}/bin/patchelf --add-rpath "$out/lib" "$program"
        done
      '';
    }
    {
      name = "fontconfig.config-links";
      tools = [ tools.python ];
      run = ''${tools.python}/bin/python3 -B ${./check-config-links.py} "$out"'';
    }
    (outputs.strip {
      paths = [
        "bin"
        "lib"
      ];
    })
    (outputs.rpaths {
      libraries = final.runtime.libraries;
      paths = [
        "bin"
        "lib"
      ];
    })
    (outputs.development {
      libraries = [
        final.freetype
        final.expat
      ];
    })
    (outputs.checkPaths {
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

# Opt-in native recipe; source and enabled features match the canonical build.
{
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
  patchelf,
  doCheck ? true,
}:
let
  helpers = import ../../../lib/native-steps.nix { inherit lib; };
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
  plan =
    helpers.unpack {
      inherit src xz;
      tar = gnutar;
    }
    ++ [
      {
        name = "fontconfig.prepare";
        cwd = "source";
        tools = [ python ];
        # patchShebangs uses this to distinguish store interpreters. Fresh
        # shells intentionally do not inherit the outer builder environment.
        run = ''
          export NIX_STORE=${lib.escapeShellArg builtins.storeDir}
          set +u
          patchShebangs .
          set -u
        '';
      }
    ]
    ++ helpers.meson {
      name = "fontconfig";
      inherit
        meson
        ninja
        pkg-config
        doCheck
        ;
      tools = [
        python
        gperf
      ];
      libraries = [
        freetype
        expat
      ];
      env.PKG_CONFIG_PATH = "${freetype}/lib/pkgconfig:${expat}/lib/pkgconfig";
      mesonFlags = [
        "-Ddoc=disabled"
        "-Dnls=disabled"
        "-Dtests=enabled"
        "-Dtests-bwrap=disabled"
        "-Dtests-external-fonts=disabled"
        "-Dtools=enabled"
        "-Dcache-build=disabled"
        "-Dxml-backend=expat"
        "-Dfontations=disabled"
      ];
    }
    ++ map (step: step // { tools = [ patchelf ]; }) (helpers.finalize { });
  runtime.libraries = [
    (lib.getLib freetype)
    (lib.getLib expat)
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

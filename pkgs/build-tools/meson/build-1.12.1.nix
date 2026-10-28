{
  lib,
  stdenv,
  fetchurl,
  python,
  bash,
  ninja,
  cmake,
  pkg-config,
  version,
  sha256,
  patches,
  mkTests,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "meson";
  inherit version patches;
  src = fetchurl {
    url = "https://github.com/mesonbuild/meson/releases/download/${version}/meson-${version}.tar.gz";
    inherit sha256;
  };
  nativeBuildInputs = [ python ];
  postPatch = ''
    substituteInPlace mesonbuild/scripts/depfixer.py \
      --replace-fail '@TVP_STORE_DIR@' '${builtins.storeDir}'
  '';
  dontConfigure = true;
  buildPhase = ''
    runHook preBuild
    python3 packaging/create_zipapp.py . --outfile meson.pyz \
      --interpreter ${python}/bin/python3 --compress
    runHook postBuild
  '';
  installPhase = ''
    runHook preInstall
    install -Dm755 meson.pyz "$out/libexec/meson.pyz"
    install -Dm755 ${./meson.sh} "$out/bin/meson"
    substituteInPlace "$out/bin/meson" \
      --replace-fail '@bash@' '${bash}/bin/bash' \
      --replace-fail '@python@' '${python}/bin/python3' \
      --replace-fail '@ninja@' '${ninja}/bin/ninja' \
      --replace-fail '@cmake@' '${cmake}/bin/cmake' \
      --replace-fail '@pkgConfig@' '${pkg-config}/bin/pkg-config' \
      --replace-fail '@out@' "$out"
    install -Dm644 ${./setup-hook.sh} "$out/nix-support/setup-hook"
    install -Dm644 man/meson.1 "$out/share/man/man1/meson.1"
    runHook postInstall
  '';
  meta = {
    description = "Meson build system with owned Python and Ninja";
    homepage = "https://mesonbuild.com/";
    license = lib.licenses.asl20;
    platforms = [ "x86_64-linux" ];
    mainProgram = "meson";
  };
  passthru = {
    tvp.deps = {
      inherit
        python
        bash
        ninja
        cmake
        pkg-config
        ;
    };
    tvp.cc = stdenv.cc;
    tests = mkTests finalAttrs.finalPackage;
  };
})

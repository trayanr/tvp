{
  lib,
  stdenv,
  fetchurl,
  python,
  bash,
  version,
  sha256,
  patches,
  mkTests,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "ninja";
  inherit version patches;
  src = fetchurl {
    name = "ninja-${version}.tar.gz";
    url = "https://github.com/ninja-build/ninja/archive/refs/tags/v${version}.tar.gz";
    inherit sha256;
  };
  nativeBuildInputs = [ python ];
  postPatch = ''
    substituteInPlace src/subprocess-posix.cc \
      --replace-fail '@TVP_SHELL@' '${bash}/bin/bash'
  '';
  dontConfigure = true;
  buildPhase = ''
    runHook preBuild
    ${python}/bin/python3 configure.py --bootstrap --with-python=${python}/bin/python3
    runHook postBuild
  '';
  installPhase = ''
    runHook preInstall
    install -Dm755 ninja "$out/bin/ninja"
    install -Dm644 misc/ninja_syntax.py "$out/share/ninja/ninja_syntax.py"
    runHook postInstall
  '';
  postInstall = ''
    mkdir -p "$out/nix-support"
    cp ${./setup-hook.sh} "$out/nix-support/setup-hook"
  '';
  meta = {
    description = "Small build system focused on speed";
    homepage = "https://ninja-build.org/";
    license = lib.licenses.asl20;
    platforms = [ "x86_64-linux" ];
    mainProgram = "ninja";
  };
  passthru = {
    tvp.deps = {
      inherit python bash;
    };
    tvp.cc = stdenv.cc;
    tests = mkTests finalAttrs.finalPackage;
  };
})

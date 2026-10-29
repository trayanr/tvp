{
  lib,
  stdenv,
  fetchurl,
  bash,
  python,
  ninja,
  rustc,
  cargo,
  patchelf,
  openssl,
  zlib,
  version,
  sha256,
  patches,
  mkTests,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "nodejs";
  inherit version patches;
  src = fetchurl {
    url = "https://nodejs.org/dist/v${version}/node-v${version}.tar.xz";
    inherit sha256;
  };
  nativeBuildInputs = [
    python
    ninja
    rustc
    cargo
    patchelf
  ];
  buildInputs = [
    openssl
    zlib
  ];
  CARGO_NET_OFFLINE = "true";
  preConfigure = ''
    export CC='${stdenv.cc}/bin/cc' CXX='${stdenv.cc}/bin/c++'
    export CARGO_HOME="$TMPDIR/cargo-home"
    substituteInPlace lib/child_process.js --replace-fail '@TVP_SHELL@' '${bash}/bin/bash'
    substituteInPlace deps/npm/node_modules/@npmcli/promise-spawn/lib/index.js \
      --replace-fail '@TVP_SHELL@' '${bash}/bin/bash'
    patchShebangs configure tools deps/npm/bin
  '';
  configureFlags = [
    "--ninja"
    "--v8-enable-temporal-support"
    "--with-intl=full-icu"
    "--shared-openssl"
    "--shared-openssl-includes=${lib.getDev openssl}/include"
    "--shared-openssl-libpath=${lib.getLib openssl}/lib"
    "--shared-zlib"
    "--shared-zlib-includes=${lib.getDev zlib}/include"
    "--shared-zlib-libpath=${lib.getLib zlib}/lib"
  ];
  buildPhase = ''
    runHook preBuild
    ninja -C out/Release -j"$NIX_BUILD_CORES" node
    runHook postBuild
  '';
  doCheck = true;
  checkPhase = ''
    runHook preCheck
    ${python}/bin/python3 tools/test.py --mode=release --timeout=120 \
      parallel/test-assert-deep parallel/test-buffer-tostring parallel/test-crypto-hash parallel/test-zlib-convenience-methods
    runHook postCheck
  '';
  installPhase = ''
    runHook preInstall
    ${python}/bin/python3 tools/install.py install --dest-dir="" --prefix="$out"
    export PATH="$out/bin:$PATH"
    patchShebangs "$out/lib/node_modules"
    # Native build tools contribute library search paths through setup; Rust
    # is only a compiler input, not a Node runtime dependency.
    patchelf --shrink-rpath "$out/bin/node"
    runHook postInstall
  '';
  meta = {
    description = "Node.js JavaScript runtime with npm, full ICU and Temporal";
    homepage = "https://nodejs.org/";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
    mainProgram = "node";
  };
  passthru = {
    tvp.deps = {
      inherit
        bash
        python
        ninja
        rustc
        cargo
        patchelf
        openssl
        zlib
        ;
    };
    tvp.cc = stdenv.cc;
    tvp.features = {
      npm = true;
      fullIcu = true;
      temporal = true;
    };
    tests = mkTests finalAttrs.finalPackage;
  };
})

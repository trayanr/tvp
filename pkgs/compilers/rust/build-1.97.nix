# Serves 1.97 onwards. Installs upstream's binary distribution; the version
# table declares this a `blob`.
{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  zlib,

  version,
  sha256,

  # Supplied by default.nix. A fork that drops this argument fails to evaluate.
  mkTests,
}:
let
  # A binary distribution exists only for targets upstream chose to build, so an
  # unlisted platform throws rather than being detected.
  triples = {
    x86_64-linux = "x86_64-unknown-linux-gnu";
  };

  triple =
    triples.${stdenv.hostPlatform.system}
      or (throw "TVP: no rust binary distribution declared for ${stdenv.hostPlatform.system}");
in
stdenv.mkDerivation (finalAttrs: {
  pname = "rustc";
  inherit version;

  src = fetchurl {
    url = "https://static.rust-lang.org/dist/rust-${version}-${triple}.tar.gz";
    inherit sha256;
  };

  nativeBuildInputs = [ autoPatchelfHook ];
  buildInputs = [
    stdenv.cc.cc.lib
    zlib
  ];

  # rlib archives carry an .rmeta section that strip removes.
  dontStrip = true;
  dontConfigure = true;
  dontBuild = true;

  postPatch = "patchShebangs .";

  installPhase = ''
    runHook preInstall
    ./install.sh --prefix="$out" --components=rustc,rust-std-${triple}
    runHook postInstall
  '';

  meta = {
    description = "The Rust compiler";
    homepage = "https://www.rust-lang.org/";
    license = [
      lib.licenses.mit
      lib.licenses.asl20
    ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = lib.attrNames triples;
    mainProgram = "rustc";
  };

  passthru = {
    inherit version;
    tvp.deps = { };

    tests = mkTests finalAttrs.finalPackage;
  };
})

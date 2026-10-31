{
  stdenv,
  version,
  sha256,
  dependency ? null,
}:
stdenv.mkDerivation {
  pname = "selector-fixture";
  inherit version;
  dontUnpack = true;
  installPhase = ''
    mkdir -p "$out"
    printf '%s\n' '${if dependency == null then "none" else dependency}' > "$out/dependency"
  '';
  passthru.tests = { };
}

{
  stdenvNoCC,
  python3,
  makeWrapper,
}:
stdenvNoCC.mkDerivation {
  name = "tvp-test-runner";
  dontUnpack = true;
  nativeBuildInputs = [ makeWrapper ];
  installPhase = ''
    mkdir -p "$out/libexec/tvp-test" "$out/bin"
    cp ${./runner.py} "$out/libexec/tvp-test/runner.py"
    cp ${./progress.py} "$out/libexec/tvp-test/progress.py"
    cp ${./attempts.py} "$out/libexec/tvp-test/attempts.py"
    makeWrapper ${python3}/bin/python3 "$out/bin/tvp-test" \
      --add-flags "$out/libexec/tvp-test/runner.py" \
      --set TVP_TEST_SYSTEM ${stdenvNoCC.hostPlatform.system}
  '';
}

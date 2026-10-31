{
  stdenvNoCC,
  python3,
  makeWrapper,
}:
stdenvNoCC.mkDerivation {
  name = "tvp-dependencies";
  dontUnpack = true;
  nativeBuildInputs = [ makeWrapper ];
  installPhase = ''
    mkdir -p "$out/libexec/tvp-dependencies" "$out/bin"
    cp ${./report.py} "$out/libexec/tvp-dependencies/report.py"
    makeWrapper ${python3}/bin/python3 "$out/bin/tvp-dependencies" \
      --add-flags "$out/libexec/tvp-dependencies/report.py" \
      --set TVP_DEPENDENCIES_SYSTEM ${stdenvNoCC.hostPlatform.system}
  '';
}

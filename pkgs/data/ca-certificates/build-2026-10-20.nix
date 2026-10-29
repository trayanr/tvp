{
  lib,
  stdenv,
  fetchurl,
  version,
  sha256,
  mkTests,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "ca-certificates";
  inherit version;
  src = fetchurl {
    url = "https://curl.se/ca/cacert-${version}.pem";
    inherit sha256;
  };
  dontUnpack = true;
  dontConfigure = true;
  dontBuild = true;
  installPhase = ''
    runHook preInstall
    install -Dm644 "$src" "$out/etc/ssl/certs/ca-bundle.crt"
    install -Dm644 ${./setup-hook.sh} "$out/nix-support/setup-hook"
    substituteInPlace "$out/nix-support/setup-hook" --replace-fail '@bundle@' "$out/etc/ssl/certs/ca-bundle.crt"
    runHook postInstall
  '';
  meta = {
    description = "Dated Mozilla CA root certificate bundle published by curl";
    homepage = "https://curl.se/docs/caextract.html";
    license = lib.licenses.mpl20;
    platforms = [ "x86_64-linux" ];
  };
  passthru = {
    tvp.deps = { };
    tests = mkTests finalAttrs.finalPackage;
  };
})

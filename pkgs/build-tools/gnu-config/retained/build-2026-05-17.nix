# GNU config has dated Git snapshots rather than numbered releases.
{
  lib,
  stdenv,
  fetchgit,
  bash,
  revision,
  version,
  sha256,
  mkTests,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "gnu-config";
  inherit version;
  src = fetchgit {
    url = "https://https.git.savannah.gnu.org/git/config.git";
    rev = revision;
    inherit sha256;
    fetchSubmodules = false;
  };
  dontConfigure = true;
  dontBuild = true;
  doCheck = true;
  checkPhase = ''
    runHook preCheck
    ( cd testsuite
      ${bash}/bin/bash config-sub.sh
      ${bash}/bin/bash config-guess.sh
    )
    runHook postCheck
  '';
  installPhase = ''
    runHook preInstall
    install -Dm755 config.guess "$out/config.guess"
    install -Dm755 config.sub "$out/config.sub"
    substituteInPlace "$out/config.guess" "$out/config.sub" \
      --replace-fail '#! /bin/sh' '#!${bash}/bin/bash'
    install -Dm644 ChangeLog-old "$out/share/doc/gnu-config/ChangeLog-old"
    printf '%s\n' '${revision}' > "$out/share/doc/gnu-config/revision"
    runHook postInstall
  '';
  meta = {
    description = "GNU system type detection and canonicalisation scripts";
    homepage = "https://savannah.gnu.org/projects/config/";
    license = {
      spdxId = "GPL-3.0-or-later WITH Autoconf-exception-generic-3.0";
      fullName = "GNU GPL v3 or later with the Autoconf distribution exception";
      free = true;
      url = "https://git.savannah.gnu.org/cgit/config.git/tree/config.guess";
    };
    platforms = lib.platforms.unix;
  };
  passthru = {
    tvp.deps = {
      inherit bash;
    };
    tvp.cc = stdenv.cc;
    tvp.revision = revision;
    tests = mkTests finalAttrs.finalPackage;
  };
})

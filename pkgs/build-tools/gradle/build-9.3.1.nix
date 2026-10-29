{
  lib,
  stdenv,
  fetchurl,
  jdk,
  python,
  bash,
  unzip,
  coreutils,
  version,
  sha256,
  mkTests,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "gradle";
  inherit version;
  src = fetchurl {
    url = "https://services.gradle.org/distributions/gradle-${version}-all.zip";
    inherit sha256;
  };
  nativeBuildInputs = [ unzip ];
  dontConfigure = true;
  dontBuild = true;
  dontStrip = true;
  installPhase = ''
    mkdir -p "$out/libexec/gradle" "$out/bin" "$out/nix-support"
    cp -a . "$out/libexec/gradle/"
    mkdir -p "$out/share/gradle"
    cp "$src" "$out/share/gradle/gradle-${version}-all.zip"
    cat > "$out/bin/gradle" <<EOF
    #!${bash}/bin/bash
    export JAVA_HOME=${jdk}
    export PATH=${jdk}/bin:${coreutils}/bin:\$PATH
    exec ${jdk}/bin/java -classpath "$out/libexec/gradle/lib/gradle-launcher-${version}.jar" org.gradle.launcher.GradleMain "\$@"
    EOF
    substitute ${./seed-wrapper.py} "$out/bin/tvp-gradle-seed-wrapper" \
      --subst-var-by python '${python}/bin/python3' \
      --subst-var-by version '${version}' \
      --subst-var-by archive "$out/share/gradle/gradle-${version}-all.zip"
    chmod +x "$out/bin/"*
    printf 'export GRADLE_HOME=%s\n' "$out/libexec/gradle" > "$out/nix-support/setup-hook"
  '';
  meta = {
    description = "Pinned Gradle build tool with owned Java runtime and offline wrapper seed";
    homepage = "https://gradle.org/";
    license = lib.licenses.asl20;
    sourceProvenance = [
      lib.sourceTypes.binaryBytecode
      lib.sourceTypes.binaryNativeCode
    ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "gradle";
  };
  passthru = {
    tvp.deps = {
      inherit
        jdk
        python
        bash
        unzip
        coreutils
        ;
    };
    distributionArchive = "${finalAttrs.finalPackage}/share/gradle/gradle-${version}-all.zip";
    tests = mkTests finalAttrs.finalPackage;
  };
})

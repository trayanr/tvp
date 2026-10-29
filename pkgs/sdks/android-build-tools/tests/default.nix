{
  pkgs,
  tvpLib,
  package,
  platform,
  zip,
}:
let
  sources = pkgs.lib.fileset.toSource {
    root = ./fixtures;
    fileset = pkgs.lib.fileset.unions [
      ./fixtures/AndroidManifest.xml
      ./fixtures/MainActivity.java
      ./fixtures/res/values/strings.xml
    ];
  };
  androidJar = "${platform}/${platform.tvp.android.componentPath}/android.jar";
in
tvpLib.tests.mkSuite {
  inherit pkgs package;
  tests = {
    version = {
      script = ''sed -n 's/^Pkg.Revision=//p' ${package}/${package.tvp.android.componentPath}/source.properties'';
      expected = package.version;
    };
    apk = {
      script = ''
        cp -r ${sources}/. project
        chmod -R u+w project
        mkdir generated classes dex
        aapt2 compile --dir project/res -o resources.zip
        aapt2 link -I ${androidJar} --manifest project/AndroidManifest.xml --java generated --min-sdk-version 24 --target-sdk-version 36 resources.zip -o unsigned.apk
        javac -source 8 -target 8 -bootclasspath ${androidJar} -d classes generated/tvp/fixture/R.java project/MainActivity.java
        d8 --lib ${androidJar} --min-api 24 --output dex classes/tvp/fixture/*.class
        zip -q -j unsigned.apk dex/classes.dex
        zipalign -p -f 4 unsigned.apk aligned.apk
        keytool -genkeypair -keystore debug.p12 -storepass tvp-test-password -keypass tvp-test-password -dname CN=TVP -alias debug -keyalg RSA -validity 3650 -noprompt > keytool.log 2>&1
        apksigner sign --ks debug.p12 --ks-key-alias debug --ks-pass pass:tvp-test-password --out signed.apk aligned.apk
        apksigner verify --verbose --min-sdk-version 24 signed.apk > signature.txt
        grep -q '^Verifies' signature.txt
        aapt2 dump badging signed.apk | grep -q "package: name='tvp.fixture'"
        printf signed-apk
      '';
      expected = "signed-apk";
      extraInputs = [
        package.tvp.deps.jdk
        zip
      ];
    };
  };
}

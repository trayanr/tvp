{
  pkgs,
  tvpLib,
  package,
}:
let
  prepare = ''
    export XDG_CACHE_HOME="$TMPDIR/cache" XDG_CONFIG_HOME="$TMPDIR/config" GRADLE_USER_HOME="$TMPDIR/gradle" ANDROID_USER_HOME="$TMPDIR/android-user"
    export CI=true FLUTTER_SUPPRESS_ANALYTICS=true DART_SUPPRESS_ANALYTICS=true FLUTTER_NO_VERSION_CHECK=true
  '';
in
tvpLib.tests.mkSuite {
  inherit pkgs package;
  tests = {
    version = {
      script =
        prepare
        + ''flutter --version --machine > version.json; python3 -c 'import json; print(json.load(open("version.json"))["frameworkVersion"])' '';
      expected = package.version;
      extraInputs = [ package.tvp.deps.python ];
    };
    widget = {
      script =
        prepare
        + ''
          flutter create --offline --no-pub --platforms=web --project-name=tvp_fixture app > create.log
          cd app
          flutter pub get --offline > pub.log
          flutter test --no-pub > test.log
          grep -q 'All tests passed' test.log
          printf widgets-ok
        '';
      expected = "widgets-ok";
    };
    web = {
      script =
        prepare
        + ''
          flutter create --offline --no-pub --platforms=web --project-name=tvp_fixture app > create.log
          cd app
          flutter pub get --offline > pub.log
          flutter build web --no-pub > build.log
          test -s build/web/main.dart.js
          test -s build/web/index.html
          printf web-ok
        '';
      expected = "web-ok";
    };
    android-aot = {
      script =
        prepare
        + ''
          flutter create --offline --no-pub --platforms=android --project-name=tvp_fixture app > create.log
          cd app
          flutter pub get --offline > pub.log
          flutter assemble -dTargetPlatform=android-arm64 -dBuildMode=release -dTargetFile=lib/main.dart \
            --output=build/aot android_aot_bundle_release_android-arm64 > build.log
          readelf -h build/aot/arm64-v8a/app.so | grep -q AArch64
          readelf --dyn-syms -W build/aot/arm64-v8a/app.so > symbols.txt
          grep -q _kDartSnapshotText symbols.txt
          grep -q _kDartSnapshotData symbols.txt
          test -s build/aot/flutter_assets/FontManifest.json
          printf android-aot-ok
        '';
      expected = "android-aot-ok";
    };
  };
}

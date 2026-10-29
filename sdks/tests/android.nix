{ tvp }:
let
  inherit (tvp.bases.default) stdenv;
  sdk = tvp.android.profiles.flutter;
in
stdenv.mkDerivation {
  name = "tvp-android-sdk-composition";
  nativeBuildInputs = [ sdk ];
  dontUnpack = true;
  dontConfigure = true;
  dontBuild = true;
  installPhase = ''
    export XDG_CACHE_HOME="$TMPDIR/cache" ANDROID_USER_HOME="$TMPDIR/android-user"
    tvp-android-sdk > first &
    first=$!
    tvp-android-sdk > second &
    second=$!
    wait "$first"
    wait "$second"
    cmp first second
    writable=$(cat first)
    test -f "$writable/.tvp-prepared"
    test -L "$writable/platforms/android-36"
    test -f "$writable/build-tools/36.0.0/package.xml"
    test -f "$writable/ndk/28.2.13676358/package.xml"
    test -x "$writable/cmdline-tools/latest/bin/android"
    # The current upstream `sdk list` contacts its repository even for
    # installed packages. Check the public CLI and local metadata offline.
    android --no-metrics --version > version.txt
    grep -q '1.1.16717390' version.txt
    printf sdk-composition-ok > "$out"
  '';
}

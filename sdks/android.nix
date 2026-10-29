{ tvp }:
let
  p = tvp.packages;
  mkSdk = args: tvp.lib.android.mkSdk ({ inherit (tvp.bases.default) stdenv; } // args);
  common = [
    p.android-commandline-tools_23_0
    p.android-platform-tools_37_0_1
  ];
in
{
  inherit mkSdk;
  profiles = {
    latest = mkSdk {
      name = "android-sdk-latest";
      components = common ++ [
        p.android-platform_37_2_r2
        p.android-build-tools_37_0_0
        p.android-ndk_30_0_16248370
      ];
    };
    flutter = mkSdk {
      name = "android-sdk-flutter-3.47";
      components = common ++ [
        p.android-platform_36_r2
        p.android-build-tools_36_0_0
        p.android-ndk_28_2_13676358
      ];
    };
  };
}

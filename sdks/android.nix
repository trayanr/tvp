{ tvp }:
let
  # These are released composition artifacts, not ordinary tool dependencies.
  # Use the exact namespace so a future prefix alias cannot move an SDK profile.
  p = tvp.canonical;
  mkSdk = args: tvp.lib.android.mkSdk ({ inherit (tvp.bases.default) stdenv; } // args);
  mkProfile =
    selector: args:
    tvp.lib.packages.tagSelection {
      namespace = "android.profiles";
      inherit selector;
      kind = "override";
      category = "composition";
      operation = "named-sdk-profile";
      reason = "Explicit named SDK composition; preserve its released artifact/profile constraints.";
    } (mkSdk args);
  common = [
    p.android-commandline-tools_23_0
    p.android-platform-tools_37_0_1
  ];
in
{
  inherit mkSdk;
  profiles = {
    latest = mkProfile "latest" {
      name = "android-sdk-latest";
      components = common ++ [
        p.android-platform_37_2_r2
        p.android-build-tools_37_0_0
        p.android-ndk_30_0_16248370
      ];
    };
    flutter = mkProfile "flutter" {
      name = "android-sdk-flutter-3.47";
      components = common ++ [
        p.android-platform_36_r2
        p.android-build-tools_36_0_0
        p.android-ndk_28_2_13676358
      ];
    };
  };
}

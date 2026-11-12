{ tvp, pkgs }:
let
  # These are released composition artifacts, not ordinary tool dependencies.
  # Use the exact namespace so a future prefix alias cannot move an SDK profile.
  p = tvp.canonical;
  candidate = import ../bases/source-gnu { };
  native = candidate.base.platform.system == tvp.bases.default.stdenv.hostPlatform.system;
  mkSdk =
    if native then
      args:
      tvp.lib.android.mkSdk (
        {
          inherit tvp;
          base = candidate.base;
          inherit (candidate.tools) bash coreutils sed;
        }
        // args
      )
    else
      args: tvp.lib.android.mkLegacySdk ({ inherit (tvp.bases.default) stdenv; } // args);
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
  retained = import ./retained-adapters.nix { inherit pkgs tvp; };
  common = [
    p.android-commandline-tools_23_0
    p.android-platform-tools_37_0_1
  ];
in
{
  inherit mkSdk;
  # Exact released construction composition for Flutter, including legacy tests.
  constructionProfiles.flutter = mkProfile "flutter" {
    name = "android-sdk-flutter-3.47";
    components = common ++ [
      retained.canonical.android-platform_36_r2
      (tvp.lib.packages.mkVersions retained.buildTools).android-build-tools_36_0_0
      (tvp.lib.packages.mkVersions retained.ndk).android-ndk_28_2_13676358
    ];
  };
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

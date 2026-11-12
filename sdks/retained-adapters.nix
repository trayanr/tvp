# Full pre-migration factories and caller view, captured before public selectors
# advance. These are construction roles, independent of public adapter ownership.
{ pkgs, tvp }:
let
  platform =
    (import ../pkgs/sdks/android-platform/legacy.nix { inherit pkgs tvp; }).recipes.android-platform;
  ndk = (import ../pkgs/sdks/android-ndk/legacy.nix { inherit pkgs tvp; }).recipes.android-ndk;
  dartBootstrap =
    (import ../pkgs/runtimes/dart-bootstrap/legacy.nix { inherit pkgs tvp; }).recipes.dart-bootstrap;
  canonical = {
    android-platform_36_r2 = (tvp.lib.packages.mkVersions platform).android-platform_36_r2;
    dart-bootstrap_3_13_0_103_1_beta =
      (tvp.lib.packages.mkVersions dartBootstrap).dart-bootstrap_3_13_0_103_1_beta;
  };
  callerTvp = tvp // {
    canonical = tvp.canonical // canonical;
    android = tvp.android // {
      profiles = tvp.android.profiles // {
        flutter = tvp.android.constructionProfiles.flutter;
      };
    };
  };
  buildTools =
    (import ../pkgs/sdks/android-build-tools/legacy.nix {
      inherit pkgs;
      tvp = callerTvp;
    }).recipes.android-build-tools;
in
{
  inherit
    platform
    ndk
    dartBootstrap
    buildTools
    canonical
    callerTvp
    ;
}

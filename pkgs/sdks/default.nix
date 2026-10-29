{ pkgs, tvp }:
tvp.lib.packages.mergeNamespaces {
  flutter = import ./flutter { inherit pkgs tvp; };
  android-cli = import ./android-cli { inherit pkgs tvp; };
  android-commandline-tools = import ./android-commandline-tools { inherit pkgs tvp; };
  android-platform-tools = import ./android-platform-tools { inherit pkgs tvp; };
  android-build-tools = import ./android-build-tools { inherit pkgs tvp; };
  android-platform = import ./android-platform { inherit pkgs tvp; };
  android-ndk = import ./android-ndk { inherit pkgs tvp; };
}

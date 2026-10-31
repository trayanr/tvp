{ lib }:
{
  # Components keep their own canonical graphs. A profile only joins paths;
  # choosing another API/NDK never rebuilds Java, Dart or the other components.
  mkSdk =
    {
      stdenv,
      components,
      name ? "android-sdk",
    }:
    let
      paths = map (p: p.tvp.android.sdkPath) components;
      duplicates = lib.filter (p: lib.count (x: x == p) paths > 1) (lib.unique paths);
      cli = lib.filter (p: lib.hasPrefix "cmdline-tools/" p.tvp.android.sdkPath) components;
    in
    if components == [ ] then
      throw "TVP Android: select at least one SDK component."
    else if duplicates != [ ] then
      throw "TVP Android: duplicate SDK paths: ${lib.concatStringsSep ", " duplicates}"
    else if lib.length cli > 1 then
      throw "TVP Android: select one command-line tools version per SDK profile."
    else
      (stdenv.mkDerivation {
        inherit name;
        dontUnpack = true;
        dontConfigure = true;
        dontBuild = true;
        installPhase = ''
          sdk="$out/libexec/android-sdk"
          mkdir -p "$sdk" "$out/bin" "$out/nix-support"
          cp ${./writable-sdk.sh} "$out/libexec/writable-sdk.sh"
          ${lib.concatMapStringsSep "\n" (p: ''
            mkdir -p "$sdk/$(dirname ${lib.escapeShellArg p.tvp.android.sdkPath})"
            ln -s '${p}/${p.tvp.android.componentPath}' "$sdk/${p.tvp.android.sdkPath}"
          '') components}
          ${lib.optionalString (cli != [ ]) (
            let
              p = lib.head cli;
            in
            ''
                ln -s '${lib.removePrefix "cmdline-tools/" p.tvp.android.sdkPath}' "$sdk/cmdline-tools/latest"
                cat > "$out/bin/android" <<EOF
              #!${stdenv.shell}
              sdk=\$("$out/bin/tvp-android-sdk")
              exec ${p}/${p.tvp.android.componentPath}/bin/android --sdk="\$sdk" "\$@"
              EOF
                cat > "$out/bin/sdkmanager" <<EOF
              #!${stdenv.shell}
              sdk=\$("$out/bin/tvp-android-sdk")
              exec ${p}/${p.tvp.android.componentPath}/bin/sdkmanager --sdk_root="\$sdk" "\$@"
              EOF
                chmod +x "$out/bin/android" "$out/bin/sdkmanager"
            ''
          )}
          substitute ${./android-sdk.sh} "$out/bin/tvp-android-sdk" \
            --subst-var-by bash '${stdenv.shell}' \
            --subst-var-by runtimePath '${lib.makeBinPath stdenv.initialPath}' \
            --subst-var-by helper "$out/libexec/writable-sdk.sh" \
            --subst-var-by sdk "$sdk" \
            --subst-var-by identity "$(basename "$out")"
          chmod +x "$out/bin/tvp-android-sdk"
          ${lib.optionalString (builtins.elem "platform-tools" paths) ''
            ln -s "$sdk/platform-tools/adb" "$out/bin/adb"
            ln -s "$sdk/platform-tools/fastboot" "$out/bin/fastboot"
          ''}
          cat > "$out/nix-support/setup-hook" <<EOF
          export ANDROID_HOME=\$("$out/bin/tvp-android-sdk")
          export ANDROID_SDK_ROOT=\$ANDROID_HOME
          EOF
        '';
        passthru = {
          inherit components;
          sdkPath = "libexec/android-sdk";
        };
      })
      // {
        __tvpComposition = true;
        __tvpSelection = {
          namespace = "android.profiles";
          selector = name;
          kind = "override";
          reason = "Explicit SDK composition of released binary artifacts.";
        };
      };
}

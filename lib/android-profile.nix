# SDK composition: installed component links first; output-dependent launchers last.
{ lib }:
{
  tvp,
  base,
  bash,
  coreutils,
  sed,
  components,
  name,
}:
final:
let
  inherit (tvp.builder) steps outputs;
  paths = map (p: p.tvp.android.sdkPath) final.components;
  duplicates = lib.filter (p: lib.count (x: x == p) paths > 1) (lib.unique paths);
  cli = lib.filter (p: lib.hasPrefix "cmdline-tools/" p.tvp.android.sdkPath) final.components;
  command = name: run: {
    inherit name run;
    tools = [
      final.coreutils
      final.sed
    ];
  };
in

{
  pname = name;
  version = "1";
  src = null;
  inherit
    base
    bash
    coreutils
    sed
    components
    ;
  sdkPath = "libexec/android-sdk";
  runtime.shell = "${final.bash}/bin/bash";
  runtime.tools = [ final.coreutils ];
  passthru = {
    inherit (final) components sdkPath;
  };
  plan =
    assert final.components != [ ] || throw "TVP Android: select at least one SDK component.";
    assert
      duplicates == [ ]
      || throw "TVP Android: duplicate SDK paths: ${lib.concatStringsSep ", " duplicates}";
    assert
      lib.length cli <= 1 || throw "TVP Android: select one command-line tools version per SDK profile.";
    steps.sequence [
      (command "android-sdk.install-links" ''
        sdk="$out/${final.sdkPath}"
        mkdir -p "$sdk"
        ${lib.concatMapStringsSep "\n" (p: ''
          mkdir -p "$sdk/$(dirname ${lib.escapeShellArg p.tvp.android.sdkPath})"
          ln -s '${p}/${p.tvp.android.componentPath}' "$sdk/${p.tvp.android.sdkPath}"
        '') final.components}
      '')
      (steps.split "android-sdk.finalize")
      (outputs.copyArtifacts { coreutils = final.coreutils; })
      (command "android-sdk.launchers" ''
        sdk="$out/${final.sdkPath}"
        mkdir -p "$out/bin" "$out/nix-support" "$out/libexec"
        cp ${./writable-sdk.sh} "$out/libexec/writable-sdk.sh"
        ${lib.optionalString (cli != [ ]) (
          let
            p = lib.head cli;
          in
          ''
              ln -s '${lib.removePrefix "cmdline-tools/" p.tvp.android.sdkPath}' "$sdk/cmdline-tools/latest"
              cat > "$out/bin/android" <<EOF
            #!${final.runtime.shell}
            sdk=\$("$out/bin/tvp-android-sdk")
            exec ${p}/${p.tvp.android.componentPath}/bin/android --sdk="\$sdk" "\$@"
            EOF
              cat > "$out/bin/sdkmanager" <<EOF
            #!${final.runtime.shell}
            sdk=\$("$out/bin/tvp-android-sdk")
            exec ${p}/${p.tvp.android.componentPath}/bin/sdkmanager --sdk_root="\$sdk" "\$@"
            EOF
              chmod +x "$out/bin/android" "$out/bin/sdkmanager"
          ''
        )}
        ${final.sed}/bin/sed \
          -e 's|@bash@|${final.runtime.shell}|g' \
          -e 's|@runtimePath@|${lib.makeBinPath final.runtime.tools}|g' \
          -e "s|@helper@|$out/libexec/writable-sdk.sh|g" \
          -e "s|@sdk@|$sdk|g" \
          -e "s|@identity@|$(basename "$out")|g" \
          ${./android-sdk.sh} > "$out/bin/tvp-android-sdk"
        chmod +x "$out/bin/tvp-android-sdk"
        ${lib.optionalString (builtins.elem "platform-tools" paths) ''
          ln -s "$sdk/platform-tools/adb" "$out/bin/adb"
          ln -s "$sdk/platform-tools/fastboot" "$out/bin/fastboot"
        ''}
        cat > "$out/nix-support/setup-hook" <<EOF
        export ANDROID_HOME=\$("$out/bin/tvp-android-sdk")
        export ANDROID_SDK_ROOT=\$ANDROID_HOME
        EOF
      '')
    ];
}

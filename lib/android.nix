{ lib }:
let
  legacy = import ./android-legacy.nix { inherit lib; };
in
{
  # Complete retained adapter for explicit non-native callers only.
  mkLegacySdk = legacy.mkSdk;
  mkSdk =
    {
      tvp,
      base,
      bash,
      coreutils,
      sed,
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
      (tvp.builder {
        recipe = import ./android-profile.nix { inherit lib; };
        args = {
          inherit
            tvp
            base
            bash
            coreutils
            sed
            components
            name
            ;
        };
        dependencyNames = spec: [
          "bash"
          "coreutils"
          "sed"
        ];
        metadata.kind = "android-sdk-composition";
        selection = {
          namespace = "compositions";
          selector = name;
          kind = "override";
          category = "composition";
          operation = "custom-sdk";
          reason = "Explicit SDK composition of released binary artifacts.";
        };
        testContext =
          package:
          tvp.lib.tests.fromPackage {
            builder = tvp.builder;
            inherit package;
          };
        mkTests = _: { };
        passthru.__tvpComposition = true;
      });
}

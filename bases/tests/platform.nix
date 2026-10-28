# Evaluation contracts: reject unsupported execution modes before producing a
# plausible-looking toolchain with the wrong loader or kernel headers.
{
  pkgs,
  tvpLib,
  bases,
}:
let
  inherit (pkgs) lib;
  inherit (tvpLib.platforms) mkNative;
  x86 = lib.systems.elaborate "x86_64-linux";
  arm = lib.systems.elaborate "aarch64-linux";
  musl = lib.systems.elaborate "x86_64-unknown-linux-musl";
  native = platform: {
    buildPlatform = platform;
    hostPlatform = platform;
    targetPlatform = platform;
  };
  rejected = args: !(builtins.tryEval (mkNative args)).success;
  profile = mkNative (native x86);
  contracts = {
    native-platform =
      profile.isNative
      && profile.system == "x86_64-linux"
      && profile.config == x86.config
      && profile.dynamicLinker == "lib/ld-linux-x86-64.so.2"
      && profile.linuxHeadersArch == "x86"
      && profile.libcLibdirAliases == [ "lib64" ];
    unsupported-native = rejected (native arm);
    cross-host = rejected ((native x86) // { hostPlatform = arm; });
    cross-build = rejected ((native x86) // { buildPlatform = arm; });
    cross-target = rejected ((native x86) // { targetPlatform = arm; });
    cross-abi = rejected ((native x86) // { hostPlatform = musl; });
    unsupported-native-abi = rejected (native musl);
    base-platforms = lib.all (
      base:
      let
        p = base.platform;
        s = base.stdenv;
      in
      p.buildPlatform.config == s.buildPlatform.config
      && p.hostPlatform.config == s.hostPlatform.config
      && p.targetPlatform.config == s.targetPlatform.config
      && p.system == s.system
      && p.dynamicLinker == profile.dynamicLinker
    ) (lib.attrValues bases);
  };
  failed = lib.attrNames (lib.filterAttrs (_: passed: !passed) contracts);
in
if failed != [ ] then
  throw "TVP: native platform contracts failed: ${lib.concatStringsSep ", " failed}"
else
  pkgs.runCommand "tvp-native-platform-interface" { } ''
    printf '%s\n' ${lib.escapeShellArgs (lib.attrNames contracts)} > "$out"
  ''

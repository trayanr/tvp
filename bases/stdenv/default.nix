# Native Linux constructor. setup.sh, builder.sh and hooks are vendored from
# nixpkgs 12228ff1752d7b7624a54e9c1af4b222b3c1073b under COPYING. Borrowed
# compatibility bases keep their original setup; the owned default uses this constructor.
{
  lib,
  config,
  platform,
}:
lib.makeOverridable (
  {
    name,
    cc,
    initialPath,
    shell,
    fixupInputs ? [ ],
  }:
  assert platform.isNative;
  let
    stdenv =
      derivation {
        inherit
          name
          cc
          initialPath
          shell
          ;
        inherit (platform.buildPlatform) system;
        builder = shell;
        args = [
          "-e"
          ./builder.sh
        ];
        setup = ./setup.sh;
        preHook = "";
        defaultNativeBuildInputs = [
          ./hooks/audit-tmpdir.sh
          ./hooks/compress-man-pages.sh
          ./hooks/make-symlinks-relative.sh
          ./hooks/move-docs.sh
          ./hooks/move-lib64.sh
          ./hooks/move-sbin.sh
          ./hooks/move-systemd-user-units.sh
          ./hooks/multiple-outputs.sh
          ./hooks/patch-shebangs.sh
          ./hooks/prune-libtool-files.sh
          ./hooks/reproducible-builds.sh
          ./hooks/set-source-date-epoch-to-latest.sh
          ./hooks/strip.sh
          cc
        ] ++ fixupInputs;
        defaultBuildInputs = [ ];
      }
      // {
        inherit cc initialPath shell;
        hasCC = true;
        inherit (platform) buildPlatform hostPlatform targetPlatform;
        inherit (platform.hostPlatform)
          system
          isDarwin
          isLinux
          isSunOS
          isCygwin
          isBSD
          isFreeBSD
          isOpenBSD
          isi686
          isx86_32
          isx86_64
          is32bit
          is64bit
          isAarch32
          isAarch64
          isMips
          isBigEndian
          ;
        extraNativeBuildInputs = [ ];
        extraBuildInputs = [ ];
        __extraImpureHostDeps = [ ];
        extraSandboxProfile = "";
        shellDryRun = "${shell} -n -O extglob";
        mkDerivation =
          (import ./make-derivation.nix {
            inherit lib config;
          } stdenv).mkDerivation;
      };
  in
  stdenv
)

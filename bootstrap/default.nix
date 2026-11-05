# Independent of flake.nix, nixpkgs, the catalogue and existing TVP bases.
{
  system ? "x86_64-linux",
}:
assert system == "x86_64-linux";
let
  adapter = import ./adapter.nix { inherit system; };
  inherit (adapter) lib derivationWithMeta;
  platform = {
    inherit system;
    isLittleEndian = true;
    is64bit = true;
    isAarch64 = false;
    isRiscV = false;
  };
  pins = builtins.fromJSON (builtins.readFile ./stage0-sources.json);
  sourceTrees = builtins.mapAttrs (
    _: pin:
    builtins.fetchTarball {
      inherit (pin) url sha256;
    }
  ) pins;
  # Nix's own builtin downloader, not a fetched curl/wget or stdenv builder.
  fetchurl =
    attrs:
    import <nix/fetchurl.nix> (
      builtins.removeAttrs attrs [ "url" ]
      // {
        url =
          builtins.replaceStrings
            [
              "mirror://gnu/"
              "mirror://savannah/"
            ]
            [
              "https://ftpmirror.gnu.org/"
              "https://download.savannah.nongnu.org/releases/"
            ]
            attrs.url;
      }
    );
  scope = rec {
    inherit lib derivationWithMeta fetchurl;
    buildPlatform = platform;
    hostPlatform = platform;
    callPackage =
      file: overrides:
      let
        f = import file;
      in
      f (builtins.intersectAttrs (builtins.functionArgs f) scope // overrides);
    stage0 = rec {
      version = "1.9.1";
      platforms = [ system ];
      stage0Arch = "AMD64";
      m2libcArch = "amd64";
      m2libcOS = "Linux";
      baseAddress = "0x00600000";
      inherit (sourceTrees)
        amd64
        m2planet
        m2mesoplanet
        mesccToolsSrc
        mesccToolsExtraSrc
        ;
      m2libc = sourceTrees.m2libc;
      callStage0 =
        file: overrides:
        let
          f = import file;
        in
        f (builtins.intersectAttrs (builtins.functionArgs f) (scope // stage0) // overrides);
      hex0 = callStage0 ./recipes/stage0-posix/hex0.nix { };
      inherit (hex0) hex0-seed;
      boot = callStage0 ./recipes/stage0-posix/mescc-tools-boot.nix { };
      inherit (boot)
        M1
        M2
        hex2
        blood-elf-0
        kaem-unwrapped
        ;
      mescc-tools = callStage0 ./recipes/stage0-posix/mescc-tools { };
      mescc-tools-extra = callStage0 ./recipes/stage0-posix/mescc-tools-extra { };
      kaem = callStage0 ./recipes/stage0-posix/kaem { };
    };
    inherit (stage0) kaem mescc-tools mescc-tools-extra;
    # Text is data written by Nix; executing a text file still requires the
    # explicitly declared source-built interpreter.
    writeText =
      name: text:
      derivationWithMeta {
        inherit name text;
        copy = "${mescc-tools-extra}/bin/cp";
        passAsFile = [ "text" ];
        builder = "${kaem}/bin/kaem";
        args = [
          "--strict"
          "--file"
          (builtins.toFile "write-text.kaem" ''
            ''${copy} ''${textPath} ''${out}
          '')
        ];
      };
    mes = callPackage ./recipes/mes { };
    ln-boot = callPackage ./recipes/ln-boot { };
    mes-libc = callPackage ./recipes/mes/libc.nix { };
    tinycc-bootstrappable = callPackage ./recipes/tinycc/bootstrappable.nix { };
    tinycc-mes = callPackage ./recipes/tinycc/mes.nix { };
  };
  tests = import ./tests.nix { inherit scope; };
in
{
  inherit (scope)
    stage0
    mes
    mes-libc
    tinycc-bootstrappable
    tinycc-mes
    ;
  inherit tests;
  compiler = scope.tinycc-mes.compiler;
  libc = scope.tinycc-mes.libs;
  sources = sourceTrees;
}

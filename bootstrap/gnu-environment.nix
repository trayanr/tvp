# Private checkpoint base DATA and driver protocol. No setup or mkDerivation.
{
  bootstrap ? import ./. { },
}:
let
  b = bootstrap;
  system = "x86_64-linux";
  lib = import ./owned-lib.nix { inherit system; };
  bash = b.gnu-bash;
  coreutils = b.gnu-tool-floor.gnu-coreutils;
  compiler = b.gnu-gcc-unwrapped;
  cc =
    (builtins.derivation {
      name = "tvp-private-gnu-environment-cc";
      inherit system;
      builder = "${bash}/bin/bash";
      PATH = "${coreutils}/bin";
      allowSubstitutes = false;
      wrapper =
        lib.replaceStrings
          [
            "@bash@"
            "@tools@"
            "@compiler@"
          ]
          [
            "${bash}/bin/bash"
            "${b.gnu-binutils}/bin:${bash}/bin:${coreutils}/bin"
            "${compiler}/bin"
          ]
          (builtins.readFile ./gnu-environment-wrapper.sh);
      passAsFile = [ "wrapper" ];
      args = [
        "-euc"
        ''
          mkdir -p "$out/bin"
          cp "$wrapperPath" "$out/bin/gcc"
          chmod +x "$out/bin/gcc"
          for name in g++ cpp cc c++ x86_64-unknown-linux-gnu-gcc x86_64-unknown-linux-gnu-g++ x86_64-unknown-linux-gnu-cpp; do
            ln -s gcc "$out/bin/$name"
          done
        ''
      ];
    })
    // {
      bintools = b.gnu-binutils;
      libc = b.gnu-libc;
      libcTools = [ ];
      defaultHardeningFlags = [ ];
    };
in
{
  inherit
    lib
    cc
    bash
    coreutils
    ;
  base = {
    name = "private-source-gnu-checkpoint";
    platform = {
      inherit system;
      config = "x86_64-unknown-linux-gnu";
      isMusl = false;
    };
    stdenv = {
      inherit cc;
      shell = "${bash}/bin/bash";
      initialPath = [
        bash
        coreutils
      ];
    };
  };
}

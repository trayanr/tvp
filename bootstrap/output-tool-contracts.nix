# Finite declared-only archive and pure runtime-metadata contracts.
{
  bootstrap ? import ./. { },
}:
let
  b = bootstrap;
  adapter = import ./gnu-environment.nix { inherit bootstrap; };
  inherit (adapter) lib bash coreutils;
  base = adapter.base;
  source = import ../lib/owned-source-steps.nix { inherit lib; };
  outputs = import ../lib/native-output-steps.nix { inherit lib; };
  builder = import ../lib/builder.nix { inherit lib; };
  archives = builtins.derivation {
    name = "tvp-output-tool-test-archives";
    system = base.platform.system;
    builder = "${bash}/bin/bash";
    PATH = lib.concatMapStringsSep ":" (p: "${p}/bin") [
      coreutils
      b.gnutar-latest
      b.xz
      b.gzip
    ];
    allowSubstitutes = false;
    args = [
      "-euc"
      ''
        mkdir -p tree/root "$out"
        printf epoch > tree/root/file
        touch -d @946684800 tree/root/file
        tar -cJf "$out/source.tar.xz" -C tree root
        tar -czf "$out/source.tar.gz" -C tree root
      ''
    ];
  };
  unpack =
    compression: findutils:
    source.unpack ({
      src = "${archives}/source.tar.${if compression == "xz" then "xz" else "gz"}";
      inherit compression findutils;
      tar = b.gnutar-latest;
      xz = b.xz;
      gzip = b.gzip;
    });
  runtime =
    dirs:
    (outputs.rpaths {
      python = b.build-python;
      binutils = b.gnu-binutils;
      patchelf = (import ./output-tool-prerequisites.nix { inherit bootstrap; }).patchelf;
      paths = [ "lib" ];
      libraries = [ ];
      base = {
        runtimeDirectories = dirs;
      }; # Deliberately no stdenv or cc.cc.
    }).run;
  dirs = [
    "${b.gnu-libc}/lib"
    "${b.gnu-libgcc}/lib/gcc/x86_64-unknown-linux-gnu/16.2.0"
  ];
  rejects = x: !(builtins.tryEval (builtins.deepSeq x true)).success;
  legacy = unpack "xz" null;
  explicit = unpack "xz" b.findutils;
in
{
  assertions = {
    explicitFind =
      builtins.elem b.findutils explicit.tools
      && lib.hasInfix "${b.findutils}/bin/find source" explicit.run;
    legacyFind = !(builtins.elem b.findutils legacy.tools) && lib.hasInfix "$(find source" legacy.run;
    noFakeCompiler = lib.hasInfix (builtins.toJSON dirs) (runtime dirs);
    serializedOrder =
      runtime dirs != runtime [
        (builtins.elemAt dirs 1)
        (builtins.elemAt dirs 0)
      ];
    emptyOverride = lib.hasInfix ''"baseDirectories":[]'' (runtime [ ]);
    context = builtins.hasContext (runtime dirs);
    rejectPlain = rejects (runtime [ "/nix/store/fake/lib" ]);
    rejectScalar = rejects (runtime "bad");
    shellArgs =
      lib.escapeShellArgs [
        "a'b"
        "x y"
      ] == "'a'\\''b' 'x y'";
  };
  unpack = builder {
    recipe =
      { }:
      _: {
        pname = "tvp-output-tool-unpack-contracts";
        version = "1";
        src = null;
        inherit base bash coreutils;
        plan = [
          {
            name = "unpack.contracts";
            tools = [
              b.gnutar-latest
              b.xz
              b.gzip
              b.findutils
            ];
            run = ''
              mkdir -p "$out"
              for mode in xz gzip; do
                mkdir "$mode"
                cd "$mode"
                if [[ "$mode" = xz ]]; then
                  ${(unpack "xz" b.findutils).run}
                else
                  ${(unpack "gzip" b.findutils).run}
                fi
                test "$(cat source/file)" = epoch
                test "$(cat source-date-epoch)" = 946684800
                cp source-date-epoch "$out/$mode-epoch"
                cd ..
              done
              mkdir missing
              cd missing
              status=0
              PATH=${
                lib.escapeShellArg (
                  lib.concatMapStringsSep ":" (p: "${p}/bin") [
                    bash
                    coreutils
                    b.gnutar-latest
                    b.xz
                  ]
                )
              } \
                ${bash}/bin/bash -euo pipefail -c ${lib.escapeShellArg legacy.run} > "$out/missing-find.log" 2>&1 || status=$?
              test "$status" = 127
              printf '%s\n' "$status" > "$out/missing-find.status"
            '';
          }
        ];
      };
    args = { };
    dependencyNames = [ ];
    metadata = { };
    selection.kind = "private-contract";
    mkTests = _: { };
  };
}

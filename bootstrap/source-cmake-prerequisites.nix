# Six opt-in prerequisites. No ordinary catalogue/default construction changes.
{
  bootstrap ? import ./. { },
}:
let
  b = bootstrap;
  composition = import ./source-base.nix { inherit bootstrap; };
  inherit (composition)
    base
    bash
    coreutils
    builder
    ;
  lib = composition.lib // {
    licenses = composition.lib.licenses // {
      zlib = "Zlib";
      bsdOriginal = "BSD-4-Clause";
      artistic1 = "Artistic-1.0-Perl";
    };
  };
  inherit (builder) steps;
  python = b.build-python;
  findutils = b.gnu-tool-floor.gnu-findutils;
  sources = builtins.mapAttrs (
    _: pin:
    import <nix/fetchurl.nix> {
      url = pin.url or (builtins.head pin.urls);
      inherit (pin) hash;
    }
  ) (builtins.fromJSON (builtins.readFile ./source-cmake-prerequisite-sources.json));
  make =
    recipe: args:
    builder {
      inherit recipe args;
      dependencyNames = builtins.attrNames args;
      metadata = { };
      selection.kind = "source-cmake-prerequisite";
      mkTests = _: { };
    };
  common = {
    tvp = {
      inherit builder;
    };
    inherit
      lib
      base
      bash
      coreutils
      python
      ;
    gnumake = b.gnu-tool-floor.gnu-make;
    gnutar = b.gnutar-latest;
    gzip = b.gzip;
    binutils = b.gnu-binutils;
    patchelf = (import ./output-tool-prerequisites.nix { inherit bootstrap; }).patchelf;
  };
  floor = [
    findutils
    b.gnused
    b.build-grep
    b.gawk
    b.diffutils
  ];
  port = {
    inherit findutils;
    sed = b.gnused;
    grep = b.build-grep;
    gawk = b.gawk;
    diffutils = b.diffutils;
  };
  # Single-stage recipes use a sibling evidence output. Zstd's existing split
  # retains logs in its artifact; the final native output drops that directory.
  qualify =
    name: package:
    (package.edit (
      s:
      s
      // {
        outputs =
          if name == "zstd" then
            [ "out" ]
          else
            [
              "out"
              "evidence"
            ];
        environment = s.environment // {
          tools = s.environment.tools ++ floor;
        };
      }
    )).editSteps
      (
        plan:
        let
          unpacked = steps.replace "source.unpack" (
            old: old // { tools = lib.unique (old.tools ++ [ findutils ]); }
          ) plan;
          logged = map (
            old:
            if
              builtins.elem old.name (
                map (p: "${name}.${p}") [
                  "configure"
                  "build"
                  "check"
                  "install"
                ]
              )
            then
              old
              // {
                run = ''
                  logdir=${if name == "zstd" then ''"$out/.tvp-evidence"'' else ''"$evidence"''}
                  mkdir -p "$logdir"
                  export CONFIG_SHELL=${bash}/bin/bash SHELL=${bash}/bin/bash TVP_SOURCE_ROOT
                  status=0
                  ${bash}/bin/bash -euc ${lib.escapeShellArg old.run} > "$logdir/${old.name}.log" 2>&1 || status=$?
                  printf '%s\n' "$status" > "$logdir/${old.name}.status"
                  if (( status )); then cat "$logdir/${old.name}.log"; exit "$status"; fi
                '';
              }
            else if name == "xz" && old.name == "output.manuals" then
              old // { tools = old.tools ++ [ findutils ]; }
            else
              old
          ) unpacked;
        in
        if name == "zstd" then
          steps.insertAfter "output.copy-artifacts" [
            {
              name = "zstd.separate-evidence";
              run = ''rm -rf "$out/.tvp-evidence"'';
            }
          ] logged
        else
          logged
      );
  perl = qualify "perl" (
    make (import ../pkgs/runtimes/perl/owned/build-5.44.0.nix) (
      common
      // port
      // {
        src = sources.perl;
        version = "5.44.0";
      }
    )
  );
  openssl = qualify "openssl" (
    make (import ../pkgs/libraries/openssl/owned/build-4.0.1.nix) (
      common
      // port
      // {
        inherit perl;
        src = sources.openssl;
        version = "4.0.1";
      }
    )
  );
  zlib = qualify "zlib" (
    make (import ../pkgs/libraries/zlib/owned/build-1.3.2.nix) (
      common
      // {
        src = sources.zlib;
        version = "1.3.2";
      }
    )
  );
  bzip2 = qualify "bzip2" (
    make (import ../pkgs/build-tools/bzip2/owned/build-1.0.8.nix) (
      common
      // {
        src = sources.bzip2;
        version = "1.0.8";
      }
    )
  );
  xz = qualify "xz" (
    make (import ../pkgs/libraries/xz/owned/build-5.8.4.nix) (
      common
      // {
        src = sources.xz;
        version = "5.8.4";
      }
    )
  );
  zstd = qualify "zstd" (
    make (import ../pkgs/libraries/zstd/build-steps-1.5.7.nix) (
      common
      // {
        inherit zlib xz;
        src = sources.zstd;
        version = "1.5.7";
        gnused = b.gnused;
        gnugrep = b.build-grep;
        diffutils = b.diffutils;
      }
    )
  );
  evidenceFor =
    name: package:
    make (
      { }:
      {
        pname = "source-${name}-evidence";
        version = package.version;
        src = null;
        inherit base bash coreutils;
        plan = [
          {
            name = "evidence.collect";
            tools = [ python ];
            run = ''
              cp -a ${if name == "zstd" then "${package.artifact}/.tvp-evidence" else package.evidence} "$out"
              chmod -R u+w "$out"
              ${python}/bin/python3 -B ${./source-prerequisite-evidence.py} ${name} "$out"
            '';
          }
        ];
      }
    ) { };
in
{
  inherit
    composition
    sources
    perl
    openssl
    zlib
    bzip2
    xz
    zstd
    ;
  evidence = builtins.mapAttrs evidenceFor {
    inherit
      perl
      openssl
      zlib
      bzip2
      xz
      zstd
      ;
  };
}

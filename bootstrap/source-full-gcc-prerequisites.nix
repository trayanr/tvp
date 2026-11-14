# Selected prerequisites for a future full compiler; no catalogue/default wiring.
{
  bootstrap ? import ./. { },
}:
let
  b = bootstrap;
  native = import ./source-native-compiler.nix { inherit bootstrap; };
  reused = import ./source-cmake-prerequisites.nix { inherit bootstrap; };
  inherit (native.composition)
    lib
    base
    bash
    coreutils
    builder
    ;
  inherit (builder) steps;
  tools = {
    inherit bash coreutils;
    inherit (reused) perl zlib zstd;
    inherit (native.tools) python pkgConfig;
    make = native.tools.make;
    binutils = native.binutils;
    tar = b.gnutar-latest;
    xz = b.xz;
    gzip = b.gzip;
    findutils = b.gnu-tool-floor.gnu-findutils;
    sed = b.gnused;
    grep = b.build-grep;
    gawk = b.gawk;
    diffutils = b.diffutils;
    patch = b.gnupatch;
    patchelf = (import ./output-tool-prerequisites.nix { inherit bootstrap; }).patchelf;
    localeTools = native.profile.libc;
  };
  sources = builtins.mapAttrs (_: import <nix/fetchurl.nix>) (
    builtins.fromJSON (builtins.readFile ./source-full-gcc-prerequisite-sources.json)
  );
  make =
    recipe: args:
    builder {
      inherit recipe args;
      dependencyNames = builtins.attrNames args;
      metadata = { };
      selection.kind = "source-full-gcc-prerequisite";
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
      ;
    inherit (tools) python binutils patchelf;
    gnumake = tools.make;
    gnutar = tools.tar;
  };
  # Reused recipes retain ordinary environment/step customization. Evidence is
  # separate from installed production outputs, including nonzero upstream runs.
  qualify =
    name: package:
    (package.edit (
      s:
      s
      // {
        outputs = [
          "out"
          "evidence"
        ];
        environment = s.environment // {
          tools = s.environment.tools ++ [
            tools.findutils
            tools.sed
            tools.grep
            tools.gawk
            tools.diffutils
          ];
        };
      }
    )).editSteps
      (
        plan:
        map (
          old:
          if old.name == "source.unpack" then
            old // { tools = old.tools ++ [ tools.findutils ]; }
          else if old.name == "output.manuals" then
            old // { tools = old.tools ++ [ tools.findutils ]; }
          else if
            builtins.elem old.name (
              map (n: "${name}.${n}") [
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
                    mkdir -p "$evidence"
                    export CONFIG_SHELL=${bash}/bin/bash SHELL=${bash}/bin/bash TVP_SOURCE_ROOT
                ${lib.optionalString (old.name == "${name}.build") "export V=1"}
                    status=0
                    ${bash}/bin/bash -euc ${lib.escapeShellArg old.run} > "$evidence/${old.name}.log" 2>&1 || status=$?
                    printf '%s\n' "$status" > "$evidence/${old.name}.status"
                    ${
                      lib.optionalString (old.name == "${name}.check") ''
                        ${tools.findutils}/bin/find . -type f \( -name '*.log' -o -name '*.trs' \) | while read -r f; do
                          mkdir -p "$evidence/raw/$(dirname "$f")"
                          cp "$f" "$evidence/raw/$f"
                        done
                      ''
                    }
                    ${
                      if old.name == "${name}.check" then
                        ""
                      else
                        ''if (( status )); then cat "$evidence/${old.name}.log"; exit "$status"; fi''
                    }
              '';
            }
          else
            old
        ) plan
      );
  # The native generation builds its own later ISL with the shared procedure.
  # Its upstream check is a separate consumer, never evidence embedded in A/F.
  libraryBase = builder.base {
    name = "source-native-libraries";
    inherit (base) platform;
    compiler = base.stdenv.cc // {
      inherit (base) runtimeDirectories;
    };
    shell = bash;
    inherit coreutils;
    tools = lib.unique (base.environment { }).tools;
    standardTools = {
      gnumake = tools.make;
      gnutar = tools.tar;
      inherit (tools)
        xz
        gzip
        python
        patchelf
        sed
        grep
        gawk
        diffutils
        findutils
        ;
    };
    construction = {
      kind = "stage";
      previous = base.name;
    };
  };
  isl = builder {
    recipe = import ../pkgs/libraries/isl/build-0.26.nix;
    args = {
      tvp = {
        inherit builder;
      };
      inherit lib;
      base = libraryBase;
      src = sources.isl;
      version = "0.28";
      inherit (native) gmp;
    };
    dependencyNames = [ "gmp" ];
    metadata = { };
    selection.kind = "source-full-gcc-prerequisite";
    testContext =
      package: (import ../lib/tests.nix { inherit lib; }).fromPackage { inherit builder package; };
    mkTests =
      package:
      lib.optionalAttrs (package.specification.upstreamCheck.enabled or true) {
        upstream = package.testContext.mkUpstream { inherit package; };
      };
  };
  libxcrypt = qualify "libxcrypt" (
    make (import ../pkgs/libraries/libxcrypt/build-4.5.2.nix) (
      common
      // {
        src = sources.libxcrypt;
        version = "4.5.2";
        inherit (tools) xz gzip perl;
      }
    )
  );
  which = qualify "which" (
    make (import ../pkgs/build-tools/which/owned/build-2.21.nix) (
      common
      // {
        src = sources.which;
        version = "2.21";
        inherit (tools) gzip;
      }
    )
  );
  ncurses = qualify "ncurses" (
    make (import ../pkgs/libraries/ncurses/owned/build-6.6.nix) (
      common
      // {
        src = sources.ncurses;
        version = "6.6";
        inherit (tools) gzip pkgConfig;
      }
    )
  );
  texinfo = qualify "texinfo" (
    make (import ../pkgs/build-tools/texinfo/owned/build-7.1.nix) (
      common
      // {
        src = sources.texinfo;
        version = "7.1";
        inherit ncurses;
        inherit (tools)
          xz
          gzip
          perl
          localeTools
          patch
          ;
      }
    )
  );
in
{
  inherit
    native
    tools
    sources
    isl
    libxcrypt
    which
    ncurses
    texinfo
    ;
  composition = native.composition;
  inherit (native) gmp mpfr mpc;
  inherit (reused) zlib zstd perl;
  python = tools.python;
}

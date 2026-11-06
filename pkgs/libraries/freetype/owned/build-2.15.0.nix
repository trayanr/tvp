# Complete owned source procedure for the selected native test-tool profile.
{
  tvp,
  lib,
  base,
  src,
  version,
  bash,
  coreutils,
  gnumake,
  gnutar,
  xz,
  gzip,
  findutils,
  python,
  binutils,
  patchelf,
  buildTools,
  pkgConfig,
  zlib,
  bzip2,
}:
final:
let
  inherit (tvp.builder) steps outputs;
  command =
    name: run:
    (final.base.environment final.environment)
    // {
      name = "freetype.${name}";
      cwd = "source";
      run = ''
        mkdir -p "$evidence"
        status=0
        ${bash}/bin/bash -euc ${lib.escapeShellArg run} > "$evidence/freetype.${name}.log" 2>&1 || status=$?
        printf '%s\n' "$status" > "$evidence/freetype.${name}.status"
        if [[ ${lib.escapeShellArg name} == check ]]; then
          ${findutils}/bin/find . -type f \( -name '*.log' -o -name '*.trs' \) | while read -r f; do
            mkdir -p "$evidence/raw/$(dirname "$f")"; cp "$f" "$evidence/raw/$f"
          done
        elif (( status )); then cat "$evidence/freetype.${name}.log"; exit "$status"; fi
      '';
    };
in
{
  pname = "freetype";
  inherit
    base
    src
    version
    bash
    coreutils
    ;
  outputs = [
    "out"
    "evidence"
  ];
  environment = {
    tools = [
      gnumake
      pkgConfig
    ] ++ buildTools;
    libraries = [
      zlib
      bzip2
    ];
  };
  development.includeDirectories = [ "include/freetype2" ];
  runtime.libraries = [
    zlib
    bzip2
  ];
  plan = steps.sequence [
    (steps.unpack {
      src = final.src;
      inherit xz gzip findutils;
      tar = gnutar;
      compression = "xz";
    })
    (steps.prepareAutotools {
      name = "freetype.prepare";
      inherit bash python;
      base = final.base;
    })
    (command "configure" ''
      export CONFIG_SHELL=${bash}/bin/bash SHELL=${bash}/bin/bash
      ./configure --prefix="$out" --with-zlib=yes --with-bzip2=yes --with-png=no --with-brotli=no --with-harfbuzz=no
    '')
    (command "build" ''${gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${bash}/bin/bash V=1'')
    (command "check" ''${gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${bash}/bin/bash check'')
    (command "install" ''${gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${bash}/bin/bash install; mkdir -p "$out/bin" "$out/lib"'')
    (outputs.shebangs {
      inherit python;
      paths = [ "bin" ];
      names = [
        "sh"
        "bash"
      ];
      interpreter = "${bash}/bin/bash";
    })
    (outputs.rpaths {
      inherit python binutils patchelf;
      base = final.base;
      paths = [
        "bin"
        "lib"
      ];
      libraries = final.runtime.libraries;
    })
    (outputs.development {
      inherit python;
      libraries = [
        zlib
        bzip2
      ];
    })
    (outputs.checkPaths {
      inherit python binutils patchelf;
      paths = [
        "bin"
        "lib"
      ];
    })
  ];
  tvp.features = {
    zlib = true;
    bzip2 = true;
    png = false;
    brotli = false;
    harfbuzz = false;
  };
  meta.platforms = [ "x86_64-linux" ];
}

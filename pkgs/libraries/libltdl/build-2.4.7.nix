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
}:
final:
let
  inherit (tvp.builder) steps outputs;
  command =
    name: run:
    (final.base.environment final.environment)
    // {
      name = "ltdl.${name}";
      cwd = "source/libltdl";
      run = ''
        mkdir -p "$evidence"
        status=0
        ${bash}/bin/bash -euc ${lib.escapeShellArg run} > "$evidence/ltdl.${name}.log" 2>&1 || status=$?
        printf '%s\n' "$status" > "$evidence/ltdl.${name}.status"
        if [[ ${lib.escapeShellArg name} == check ]]; then
          ${findutils}/bin/find . -type f \( -name '*.log' -o -name '*.trs' \) | while read -r f; do
            mkdir -p "$evidence/raw/$(dirname "$f")"; cp "$f" "$evidence/raw/$f"
          done
        elif (( status )); then cat "$evidence/ltdl.${name}.log"; exit "$status"; fi
      '';
    };
in
{
  pname = "ltdl";
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
      findutils
    ] ++ buildTools;
    libraries = [ ];
  };
  runtime.libraries = [ ];
  plan = steps.sequence [
    (steps.unpack {
      src = final.src;
      inherit xz gzip findutils;
      tar = gnutar;
      compression = "xz";
    })
    (steps.prepareAutotools {
      name = "ltdl.prepare";
      cwd = "source/libltdl";
      inherit bash python;
      base = final.base;
    })
    (command "configure" ''
      export CONFIG_SHELL=${bash}/bin/bash SHELL=${bash}/bin/bash
      ./configure --prefix="$out" --enable-ltdl-install --enable-shared --disable-static
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
      libraries = [ ];
    })
    (outputs.checkPaths {
      inherit python binutils patchelf;
      paths = [
        "bin"
        "lib"
      ];
    })
  ];
  meta.platforms = [ "x86_64-linux" ];
}

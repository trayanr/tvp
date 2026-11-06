{
  tvp,
  lib,
  base,
  src,
  bash,
  coreutils,
  buildTools,
  gnumake,
  gnutar,
  gzip,
  findutils,
  python,
  binutils,
  patchelf,
  expect,
}:
final:
let
  inherit (tvp.builder) steps outputs;
  command =
    name: run:
    (final.base.environment final.environment)
    // {
      name = "dejagnu.${name}";
      cwd = "source";
      run = ''
        export TVP_SOURCE_ROOT
        mkdir -p "$evidence"
        status=0
        ${bash}/bin/bash -euc ${lib.escapeShellArg run} > "$evidence/dejagnu.${name}.log" 2>&1 || status=$?
        printf '%s\n' "$status" > "$evidence/dejagnu.${name}.status"
        ${
          if name == "check" then
            ''
              ${findutils}/bin/find build -type f \( -name '*.sum' -o -name '*.log' \) | while read -r f; do
                mkdir -p "$evidence/raw/$(dirname "$f")"; cp "$f" "$evidence/raw/$f"
              done
            ''
          else
            ''if (( status )); then cat "$evidence/dejagnu.${name}.log"; exit "$status"; fi''
        }
      '';
    };
in
{
  pname = "dejagnu";
  version = "1.6.3";
  inherit
    base
    src
    bash
    coreutils
    ;
  outputs = [
    "out"
    "evidence"
  ];
  environment = {
    tools = buildTools ++ [ expect ];
    libraries = [ ];
  };
  plan = steps.sequence [
    (steps.unpack {
      src = final.src;
      tar = gnutar;
      inherit gzip findutils;
      compression = "gzip";
    })
    (steps.prepareAutotools {
      name = "dejagnu.prepare";
      inherit bash python;
      base = final.base;
    })
    (steps.shebangs {
      name = "dejagnu.shells";
      inherit python;
      names = [
        "sh"
        "bash"
      ];
      paths = [
        "runtest"
        "dejagnu"
        "commands/help.sh"
        "testsuite"
      ];
      interpreter = "${bash}/bin/bash";
    })
    (command "configure" ''
      export CONFIG_SHELL=${bash}/bin/bash SHELL=${bash}/bin/bash
      # The auxiliary launcher also execs a shell for support commands.
      # Bind its literal fallbacks, including non-executable help.sh data.
      sed -i 's|bashbin=/bin/bash|bashbin=${bash}/bin/bash|; s|exec /bin/sh |exec ${bash}/bin/bash |' dejagnu
      sed -i '1s|^#!/bin/sh$|#!${bash}/bin/bash|' commands/help.sh
      mkdir build; cd build
      ../configure --prefix="$out"
    '')
    (command "build" ''cd build; ${gnumake}/bin/make -j"$NIX_BUILD_CORES"'')
    (command "check" ''
      export HOME="$TMPDIR" LOGNAME=builder TERM=xterm CONFIG_SHELL=${bash}/bin/bash SHELL=${bash}/bin/bash
      cd build
      ${coreutils}/bin/timeout 300 ${gnumake}/bin/make check < /dev/zero
    '')
    (command "install" ''
      cd build; ${gnumake}/bin/make install
      ln -s ${expect}/bin/expect "$out/bin/expect"
      mkdir -p "$out/nix-support"
      cp "$TVP_SOURCE_ROOT/source-date-epoch" "$out/nix-support/source-date-epoch"
    '')
    (outputs.shebangs {
      inherit python;
      names = [
        "sh"
        "bash"
      ];
      paths = [
        "bin"
        "share/dejagnu"
      ];
      interpreter = "${bash}/bin/bash";
    })
    (outputs.development {
      inherit python;
      libraries = [ expect ];
    })
  ];
  meta.platforms = [ "x86_64-linux" ];
}

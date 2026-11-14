# Complete alsa-lib 1.2.16.1 procedure; earlier providers stay explicit.
{
  tvp,
  lib,
  base,
  src,
  version,
}:
final:
let
  context = tvp.builder.forBase final.base;
  inherit (context) steps outputs tools;
  command =
    name: run:
    (final.base.environment final.environment)
    // {
      name = "alsa-lib.${name}";
      cwd = "source";
      run = ''
          mkdir -p "$evidence"
          status=0
        export TVP_SOURCE_ROOT
          ${final.bash}/bin/bash -euo pipefail -c ${lib.escapeShellArg run} > "$evidence/${name}.log" 2>&1 || status=$?
          cat "$evidence/${name}.log"
          printf '%s\n' "$status" > "$evidence/${name}.status"
          test "$status" = 0
      '';
    };
  make = ''${tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${final.bash}/bin/bash'';
in
{
  pname = "alsa-lib";
  artifactName = "${final.pname}-${final.version}";
  inherit
    base
    src
    version
    ;
  inherit (tools) bash coreutils;
  outputs = [
    "out"
    "evidence"
  ];
  environment = {
    tools = [
      tools.gnumake
      tools.python
      tools.sed
      tools.grep
      tools.gawk
      tools.diffutils
      tools.findutils
    ];
    libraries = [ ];
  };
  runtime.libraries = [ ];
  plan = steps.sequence [
    {
      name = "source.unpack";
      tools = [
        tools.gnutar
        tools.bzip2
        tools.findutils
      ];
      run = ''
        mkdir source
        ${tools.bzip2}/bin/bzip2 -dc ${final.src} | ${tools.gnutar}/bin/tar -xf - --strip-components=1 -C source
        chmod -R u+w source
        epoch=$(${tools.findutils}/bin/find source -type f -printf '%T@\n' | sort -n | tail -n1)
        printf '%s\n' "''${epoch%%.*}" > source-date-epoch
      '';
    }
    (steps.prepareAutotools {
      name = "alsa-lib.prepare";
    })
    (command "configure" ''
      export CONFIG_SHELL=${final.bash}/bin/bash SHELL=${final.bash}/bin/bash
      ./configure --prefix="$out" --libdir="$out/lib" --disable-python
    '')
    (command "build" make)
    (command "install" "${make} install")
    (command "receipt" ''
      mkdir -p "$out/nix-support"
      cp "$TVP_SOURCE_ROOT/source-date-epoch" "$out/nix-support/source-date-epoch"
    '')
    (steps.split "alsa-lib.finalize")
    (outputs.copyArtifacts {
      outputs = final.outputs;
    })
    {
      name = "alsa-lib.relocate";
      tools = [ tools.python ];
      run = ''${tools.python}/bin/python3 -B ${../jdk-support-relocate.py} "$out" "$TVP_ARTIFACT_ROOT" ${
        if builtins.elem "evidence" final.outputs then
          ''"$evidence" "''${TVP_ARTIFACT_OUTPUTS[evidence]}"''
        else
          ""
      }'';
    }
    (outputs.shebangs {
      paths = [
        "bin"
        "lib"
      ];
      names = [
        "sh"
        "bash"
      ];
      interpreter = "${final.bash}/bin/bash";
    })
    (outputs.strip {
      paths = [
        "bin"
        "lib"
      ];
    })
    (outputs.rpaths {
      libraries = final.runtime.libraries;
      paths = [
        "bin"
        "lib"
      ];
    })
    (outputs.development {
      libraries = [ ];
    })
    (outputs.checkPaths {
      paths = [
        "bin"
        "lib"
      ];
    })
  ];
  tvp.features = {
    python = false;
    shared = true;
    static = false;
  };
  meta = {
    description = "ALSA userspace sound library";
    homepage = "https://www.alsa-project.org/";
    license = lib.licenses.lgpl21Plus;
    platforms = [ "x86_64-linux" ];
  };
}

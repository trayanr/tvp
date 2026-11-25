# Complete freetype 2.15.0 procedure; earlier providers stay explicit.
{
  tvp,
  lib,
  base,
  src,
  version,
  bzip2,
  png ? null,
  pkg-config,
  zlib,
}:
final:
let
  context = tvp.builder.forBase final.base;
  inherit (context) steps outputs tools;
  command =
    name: run:
    (final.base.environment final.environment)
    // {
      name = "freetype.${name}";
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
  withPng = final.png != null;
in
{
  pname = "freetype";
  artifactName = "${final.pname}-${final.version}";
  inherit
    base
    src
    version
    pkg-config
    zlib
    bzip2
    png
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
      tools.xz
      final.pkg-config
    ];
    libraries = [
      final.zlib
      final.bzip2
    ] ++ lib.optional withPng final.png;
  };
  runtime.libraries = final.environment.libraries;
  plan = steps.sequence [
    (steps.unpack {
      src = final.src;
      compression = "xz";
    })
    (steps.prepareAutotools {
      name = "freetype.prepare";
    })
    (command "configure" ''
      export CONFIG_SHELL=${final.bash}/bin/bash SHELL=${final.bash}/bin/bash
      ./configure --prefix="$out" --libdir="$out/lib" \
        --with-zlib=yes --with-bzip2=yes --with-png=${if withPng then "yes" else "no"} \
        --with-brotli=no --with-harfbuzz=no
    '')
    (command "build" make)
    (command "check-profile" ''
      # The release archive ships no executable regression suite or check target.
      # Validate the configured modules; installed compressed-font consumers run separately.
      ${tools.grep}/bin/grep '^#define FT_CONFIG_OPTION_SYSTEM_ZLIB' builds/unix/ftoption.h
      ${tools.grep}/bin/grep '^#define FT_CONFIG_OPTION_USE_BZIP2' builds/unix/ftoption.h
      ${lib.optionalString withPng ''
        ${tools.grep}/bin/grep '^#define FT_CONFIG_OPTION_USE_PNG' builds/unix/ftoption.h
      ''}
    '')
    (command "install" "${make} install")
    (command "receipt" ''
      mkdir -p "$out/nix-support"
      cp "$TVP_SOURCE_ROOT/source-date-epoch" "$out/nix-support/source-date-epoch"
    '')
    (steps.split "freetype.finalize")
    (outputs.copyArtifacts {
      outputs = final.outputs;
    })
    {
      name = "freetype.relocate";
      tools = [ tools.python ];
      run = ''${tools.python}/bin/python3 -B ${../jdk-support-relocate.py} "$out" "$TVP_ARTIFACT_ROOT" ${
        if builtins.elem "evidence" final.outputs then
          ''"$evidence" "''${TVP_ARTIFACT_OUTPUTS[evidence]}"''
        else
          ""
      }'';
    }
    (outputs.shebangs {
      paths = [ "lib" ];
      names = [
        "sh"
        "bash"
      ];
      interpreter = "${final.bash}/bin/bash";
    })
    (outputs.strip {
      paths = [ "lib" ];
    })
    (outputs.rpaths {
      libraries = final.runtime.libraries;
      paths = [ "lib" ];
    })
    (outputs.development {
      libraries = final.runtime.libraries;
    })
    (outputs.checkPaths {
      paths = [ "lib" ];
    })
  ];
  development.includeDirectories = [ "include/freetype2" ];
  tvp.features = {
    zlib = true;
    bzip2 = true;
    png = withPng;
    brotli = false;
    harfbuzz = false;
    shared = true;
    static = true;
  };
  meta = {
    description = "Font rendering library with compressed-font and embedded bitmap support";
    homepage = "https://freetype.org/";
    license = lib.licenses.ftl;
    platforms = [ "x86_64-linux" ];
  };
}

# Ordinary native 2.15.0 only; retained construction and historical profiles use independent recipes.
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
  python,
  binutils,
  patchelf,
  sed,
  grep,
  gawk,
  diffutils,
  findutils,
  xz,
  pkg-config,
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
        export TVP_SOURCE_ROOT
          ${final.bash}/bin/bash -euo pipefail -c ${lib.escapeShellArg run} > "$evidence/${name}.log" 2>&1 || status=$?
          cat "$evidence/${name}.log"
          printf '%s\n' "$status" > "$evidence/${name}.status"
          test "$status" = 0
      '';
    };
  make = ''${final.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${final.bash}/bin/bash'';
in
{
  pname = "freetype";
  artifactName = "${final.pname}-${final.version}";
  inherit
    base
    src
    version
    bash
    coreutils
    gnumake
    gnutar
    python
    binutils
    patchelf
    sed
    grep
    gawk
    diffutils
    findutils
    xz
    pkg-config
    zlib
    bzip2
    ;
  outputs = [
    "out"
    "evidence"
  ];
  environment = {
    tools = [
      final.gnumake
      final.python
      final.sed
      final.grep
      final.gawk
      final.diffutils
      final.findutils
      final.xz
      final.pkg-config
    ];
    libraries = [
      final.zlib
      final.bzip2
    ];
  };
  runtime.libraries = [
    final.zlib
    final.bzip2
  ];
  plan = steps.sequence [
    (steps.unpack {
      src = final.src;
      tar = final.gnutar;
      xz = final.xz;
      findutils = final.findutils;
      compression = "xz";
    })
    (steps.prepareAutotools {
      name = "freetype.prepare";
      bash = final.bash;
      python = final.python;
      base = final.base;
    })
    (command "configure" ''
      export CONFIG_SHELL=${final.bash}/bin/bash SHELL=${final.bash}/bin/bash
      ./configure --prefix="$out" --libdir="$out/lib" --with-zlib=yes --with-bzip2=yes --with-png=no --with-brotli=no --with-harfbuzz=no
    '')
    (command "build" make)
    (command "check-profile" ''
      # The release archive ships no executable regression suite or check target.
      # Validate the configured modules; installed compressed-font consumers run separately.
      ${final.grep}/bin/grep '^#define FT_CONFIG_OPTION_SYSTEM_ZLIB' builds/unix/ftoption.h
      ${final.grep}/bin/grep '^#define FT_CONFIG_OPTION_USE_BZIP2' builds/unix/ftoption.h
    '')
    (command "install" "${make} install")
    (command "receipt" ''
      mkdir -p "$out/nix-support"
      cp "$TVP_SOURCE_ROOT/source-date-epoch" "$out/nix-support/source-date-epoch"
    '')
    (steps.split "freetype.finalize")
    (tvp.builder.outputs.copyArtifacts {
      coreutils = final.coreutils;
      outputs = final.outputs;
    })
    {
      name = "freetype.relocate";
      tools = [ final.python ];
      run = ''${final.python}/bin/python3 -B ${../../jdk-support-relocate.py} "$out" "$TVP_ARTIFACT_ROOT" ${
        if builtins.elem "evidence" final.outputs then
          ''"$evidence" "''${TVP_ARTIFACT_OUTPUTS[evidence]}"''
        else
          ""
      }'';
    }
    (outputs.shebangs {
      python = final.python;
      paths = [ "lib" ];
      names = [
        "sh"
        "bash"
      ];
      interpreter = "${final.bash}/bin/bash";
    })
    (outputs.strip {
      python = final.python;
      binutils = final.binutils;
      paths = [ "lib" ];
    })
    (outputs.rpaths {
      python = final.python;
      binutils = final.binutils;
      patchelf = final.patchelf;
      base = final.base;
      libraries = final.runtime.libraries;
      paths = [ "lib" ];
    })
    (outputs.development {
      python = final.python;
      libraries = [
        final.zlib
        final.bzip2
      ];
    })
    (outputs.checkPaths {
      python = final.python;
      binutils = final.binutils;
      patchelf = final.patchelf;
      paths = [ "lib" ];
    })
  ];
  development.includeDirectories = [ "include/freetype2" ];
  tvp.features = {
    zlib = true;
    bzip2 = true;
    png = false;
    brotli = false;
    harfbuzz = false;
    shared = true;
    static = true;
  };
  meta = {
    description = "Font rendering library with zlib and bzip2 compressed-font support";
    homepage = "https://freetype.org/";
    license = lib.licenses.ftl;
    platforms = [ "x86_64-linux" ];
  };
}

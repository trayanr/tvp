# Native source-owned file/libmagic with compression and a compiled magic database.
# Kept separate from the stdenv procedure used by catalogue releases.
{
  lib,
  base,
  bash,
  coreutils,
  src,
  version,
  gnutar,
  gzip,
  gnumake,
  zlib,
  xz,
  bzip2,
  zstd,
  tools,
}:
final:
let
  command =
    name: run:
    (final.base.environment final.environment)
    // {
      name = "file.${name}";
      cwd = "source";
      inherit run;
    };
in
{
  pname = "source-gcc-test-file";
  inherit
    src
    version
    base
    bash
    coreutils
    ;
  environment = {
    tools = [ gnumake ] ++ tools;
    libraries = [
      zlib
      xz
      bzip2
      zstd
    ];
  };
  plan = [
    {
      name = "file.unpack";
      tools = [
        gnutar
        gzip
      ];
      run = ''
        mkdir source
        tar xf ${final.src} -C source --strip-components=1
        chmod -R u+w source
      '';
    }
    (command "configure" ''
      export SHELL=${bash}/bin/bash CONFIG_SHELL=${bash}/bin/bash
      ${bash}/bin/bash ./configure --prefix="$out" --disable-dependency-tracking
    '')
    (command "build" ''
      ${gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${bash}/bin/bash
    '')
    (command "check" ''
      ${gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${bash}/bin/bash check
    '')
    (command "install" ''
      ${gnumake}/bin/make SHELL=${bash}/bin/bash install
      "$out/bin/file" --version
      "$out/bin/file" -b ${base.stdenv.cc}/bin/cc | grep -E 'script|ELF|symbolic link'
    '')
  ];
}

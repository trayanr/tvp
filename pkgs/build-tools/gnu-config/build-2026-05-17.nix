# Dated Git snapshot: install pristine scripts before binding the runtime shell.
# Shipped test execution is an independent test derivation, never production work.
{
  tvp,
  lib,
  base,
  src,
  version,
  revision,
  bash,
  coreutils,
  sed,
  gawk,
  grep,
}:
final:
let
  command =
    name: run:
    (final.base.environment final.environment)
    // {
      name = "gnu-config.${name}";
      inherit run;
      cwd = "source";
    };
in
{
  pname = "gnu-config";
  inherit
    base
    src
    version
    bash
    coreutils
    sed
    gawk
    grep
    revision
    ;
  dependencyProviders = {
    bash = final.bash;
    coreutils = final.coreutils;
    sed = final.sed;
    gawk = final.gawk;
    grep = final.grep;
  };
  environment = {
    tools = [
      final.bash
      final.coreutils
      final.sed
      final.gawk
      final.grep
    ];
    libraries = [ ];
  };
  runtime = {
    bash = final.bash;
  };
  plan = tvp.builder.steps.sequence [
    {
      name = "source.copy";
      run = ''
        cp -R ${final.src} source
        chmod -R u+w source
      '';
    }
    (command "install" ''
      install -Dm755 config.guess "$out/config.guess"
      install -Dm755 config.sub "$out/config.sub"
      install -Dm644 ChangeLog-old "$out/share/doc/gnu-config/ChangeLog-old"
      printf '%s\n' '${final.revision}' > "$out/share/doc/gnu-config/revision"
    '')
    (tvp.builder.steps.split "gnu-config.finalize")
    (tvp.builder.outputs.copyArtifacts { coreutils = final.coreutils; })
    {
      name = "gnu-config.runtime-shell";
      tools = [ final.sed ];
      run = ''
        ${final.sed}/bin/sed -i '1s|^#! /bin/sh$|#!${final.runtime.bash}/bin/bash|' "$out/config.guess" "$out/config.sub"
      '';
    }
  ];
  meta = {
    description = "GNU system type detection and canonicalisation scripts";
    homepage = "https://savannah.gnu.org/projects/config/";
    license = {
      spdxId = "GPL-3.0-or-later WITH Autoconf-exception-generic-3.0";
      fullName = "GNU GPL v3 or later with the Autoconf distribution exception";
      free = true;
      url = "https://git.savannah.gnu.org/cgit/config.git/tree/config.guess";
    };
    platforms = lib.platforms.unix;
  };
  tvp = {
    revision = final.revision;
  };
}

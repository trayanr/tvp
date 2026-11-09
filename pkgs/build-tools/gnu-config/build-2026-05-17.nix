# Dated Git snapshot: run shipped tests with declared fixture interpreters,
# then install the two scripts with the selected runtime Bash. No compiler output.
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
    ;
  environment = {
    tools = [
      bash
      coreutils
      sed
      gawk
      grep
    ];
    libraries = [ ];
  };
  runtime = {
    inherit bash;
  };
  plan = tvp.builder.steps.sequence [
    {
      name = "source.copy";
      run = ''
        cp -R ${final.src} source
        chmod -R u+w source
      '';
    }
    (command "upstream" ''
      cd testsuite
      # The harness generates executable uname/ldd mocks. Bind only their two
      # interpreter directives; keep every assertion and fixture datum intact.
      test "$(${grep}/bin/grep -c '^#!/bin/sh$' config-guess.sh)" = 2
      ${sed}/bin/sed 's|^#!/bin/sh$|#!${final.bash}/bin/bash|' \
        config-guess.sh > config-guess-selected.sh
      sub=0; guess=0
      ${final.bash}/bin/bash config-sub.sh > config-sub.log 2>&1 || sub=$?
      ${final.bash}/bin/bash config-guess-selected.sh > config-guess.log 2>&1 || guess=$?
      cat config-sub.log config-guess.log
      printf '%s\n' "$sub" > config-sub.exit
      printf '%s\n' "$guess" > config-guess.exit
      printf 'config-sub.sh exit=%s; config-guess.sh exit=%s\n' "$sub" "$guess"
      if (( sub )); then exit "$sub"; fi
      if (( guess )); then exit "$guess"; fi
      for fixture in uname ldd; do
        IFS= read -r interpreter < "$fixture"
        test "$interpreter" = '#!${final.bash}/bin/bash'
        printf '%s: %s\n' "$fixture" "$interpreter"
      done > fixture-interpreters
    '')
    (command "install" ''
      install -Dm755 config.guess "$out/config.guess"
      install -Dm755 config.sub "$out/config.sub"
      ${sed}/bin/sed -i '1s|^#! /bin/sh$|#!${final.runtime.bash}/bin/bash|' "$out/config.guess" "$out/config.sub"
      install -Dm644 ChangeLog-old "$out/share/doc/gnu-config/ChangeLog-old"
      printf '%s\n' '${revision}' > "$out/share/doc/gnu-config/revision"
      mkdir -p "$out/nix-support/upstream"
      cp testsuite/config-{sub,guess}.{log,exit} "$out/nix-support/upstream/"
      cp testsuite/fixture-interpreters "$out/nix-support/upstream/"
    '')
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
    inherit revision;
  };
}

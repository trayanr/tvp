# Ruby 2.7.4–2.7.8 initialize implicit CFLAGS before capturing Ruby's cflags.
# Follow 3.0's reset of implicit CFLAGS so declared flags reach extensions,
# preserving explicit user CFLAGS and the normal optimization/debug/warnings.
{ lib, fetchurl, ... }@args:
(import ./build-2.2.nix args).overrideAttrs (old: {
  postPatch =
    (old.postPatch or "")
    + ''
      substituteInPlace configure --replace-fail $'\ncflagspat=\n' \
        $'\nif test -z "''${ac_env_CFLAGS_set}"; then\n  { CFLAGS=; unset CFLAGS; }\nfi\n\ncflagspat=\n'
    '';
})

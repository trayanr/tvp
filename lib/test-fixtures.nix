# Lazy, test-only providers. Declaring this catalogue realizes no fixture.
rec {
  sentinel = (import ../bases/source-gnu/tests/probes.nix { }).sentinel;
  alternateSource = (import ../bootstrap/source-cmake-prerequisite-tests.nix { }).alternate;
  forBase =
    {
      builder,
      base,
      tools ? base.tools,
      bash ? base.shell,
      coreutils ? base.coreutils,
    }:
    {
      inherit sentinel alternateSource;
      # Preserve the existing explicit GNU locale-data source and its policy.
      # This fixture requires a GNU-libc test base with localedef and locale.
      gnuLocale = import ./tests/gnu-locale.nix {
        inherit
          builder
          base
          bash
          coreutils
          ;
        tar = tools.gnutar;
        xz = tools.xz;
        libc = base.compiler.libc;
      };
    };
}

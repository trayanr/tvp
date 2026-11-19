# One suite, shared by every readline version. Never fork it per builder: a
# test that exists only for newer versions cannot detect drift in an older one.
# Guards select whole tests; they never edit a test body.
#
# readline installs no useful executable, so every test compiles against the
# headers and links the library — which is how every consumer uses it.
{
  package,
  lib,
  context,
}:
let
  readline = package;
  # Headers belong to construction; actual loaded-library/terminfo expectations
  # follow an effective runtime edit rather than a captured original provider.
  runtimeNcurses = builtins.head package.runtime.libraries;
  inherit (readline.tvp) features;

  # Linking -lncursesw by name is what makes these work against a static-only
  # readline, so ncurses has to be present at link time rather than arriving
  # through libreadline.so's own DT_NEEDED.
  cc = [
    readline.tvp.deps.ncurses
  ];
in
context.mkSuite {
  inherit package;
  tools = readline.specification.environment.tools;
  libraries = [
    readline
    readline.tvp.deps.ncurses
  ];

  tests = {
    version = {
      script = ''
        cc ${./fixtures/version.c} -lreadline -lncursesw -o version
        ./version
      '';
      # A three-part tarball is a patch rollup and reports its major.minor:
      # 8.2.13 carries AC_INIT(readline, 8.2). A letter suffix is not a rollup —
      # 4.2a is its own release and reports 4.2a.
      expected =
        if builtins.match "[0-9]+\\.[0-9]+\\.[0-9]+" readline.version != null then
          lib.versions.majorMinor readline.version
        else
          readline.version;
      libraries = [ readline ] ++ cc;
    };
  }

  # 2.0 and 2.1 compile the history functions into libreadline.a and ship no
  # separate archive, so there is nothing for -lhistory to find.
  // lib.optionalAttrs (features.history or true) {
    history = {
      script = ''
        # Historical headers declare f(); retain the pre-C23 consumer dialect.
        cc -std=gnu17 ${./fixtures/history.c} -lreadline -lhistory -lncursesw -o history
        ./history
      '';
      expected = "2 tvp";
      libraries = [ readline ] ++ cc;
    };
  }

  # A static-only readline has no .so for ldd to inspect, and linking the
  # archive says nothing about what the library itself carries.
  // lib.optionalAttrs (features.shared or true) {
    # Proves the declared ncurses is actually linked: without a terminfo-backed
    # curses, readline cannot resolve a terminal's capabilities.
    terminal = {
      script = ''
        cc ${./fixtures/version.c} -lreadline -o version
        LD_TRACE_LOADED_OBJECTS=1 ./version > loaded
        grep -F '${runtimeNcurses}/lib/libncursesw.so.6' loaded >/dev/null
        echo 1
      '';
      expected = "1";
      libraries = [ readline ] ++ cc;
    };
  };
}

// import ./installed-contract.nix { inherit package lib context; }
// lib.optionalAttrs features.shared {
  line-edit-history = import ./installed-terminal.nix { inherit package lib context; };
}

// import ../../terminal-source-edit-tests.nix { inherit package lib context; }

// lib.optionalAttrs (features.finalizationContracts or true) (
  import ../../terminal-finalization-tests.nix { inherit package lib context; }
)

// lib.optionalAttrs (features.shared && !features.static) (
  import ./installed-native-contract.nix { inherit package lib context; }
)

// lib.optionalAttrs (package.specification ? upstreamCheck && package.specification.doCheck) {
  upstream = context.mkUpstream { inherit package; };
}

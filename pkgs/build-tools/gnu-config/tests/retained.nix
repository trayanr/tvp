{
  pkgs,
  tvpLib,
  package,
}:
tvpLib.tests.mkSuite {
  inherit pkgs package;
  tests = {
    layout = {
      script = ''
        test -x ${package}/config.guess || exit 1
        test -x ${package}/config.sub || exit 1
        for script in config.guess config.sub; do
          IFS= read -r shebang < ${package}/$script || exit 1
          test "$shebang" = '#!${package.tvp.deps.bash}/bin/bash' || exit 1
          actual=$(${package}/$script --time-stamp) || exit 1
          test "$actual" = '2026-05-17' || exit 1
        done
        grep -q '^428664896cf9e92d264976a960c76660938dffce$' ${package}/share/doc/gnu-config/revision || exit 1
        echo ok
      '';
      expected = "ok";
    };
    native = {
      script = ''
        # config.guess compiles its libc detection probe with this owned compiler.
        export CC_FOR_BUILD=${package.tvp.cc}/bin/cc
        guessed=$(${package}/config.guess) || exit 1
        test "$guessed" = x86_64-pc-linux-gnu || exit 1
        canonical=$(${package}/config.sub "$guessed") || exit 1
        test "$canonical" = "$guessed" || exit 1
        echo "$canonical"
      '';
      expected = "x86_64-pc-linux-gnu";
      extraInputs = [ package.tvp.cc ];
    };
    aliases = {
      script = ''
        actual=$(${package}/config.sub amd64-linux) || exit 1
        test "$actual" = x86_64-pc-linux-gnu || exit 1
        actual=$(${package}/config.sub aarch64-linux-gnu) || exit 1
        test "$actual" = aarch64-unknown-linux-gnu || exit 1
        actual=$(${package}/config.sub arm-none-eabi) || exit 1
        test "$actual" = arm-none-eabi || exit 1
        actual=$(${package}/config.sub x86_64-w64-mingw32) || exit 1
        test "$actual" = x86_64-w64-mingw32 || exit 1
        if ${package}/config.sub invalid-tvp-not-a-machine >invalid.out 2>invalid.err; then exit 1; fi
        grep -q 'Invalid configuration' invalid.err || exit 1
        echo ok
      '';
      expected = "ok";
    };
  };
}

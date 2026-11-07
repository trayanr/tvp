{
  pkgs,
  tvpLib,
  package,
}:
tvpLib.tests.mkSuite {
  inherit pkgs package;
  tests = {
    version = {
      script = ''
        ${package}/bin/diff --version | head -1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?'
      '';
      expected = package.version;
    };
    operation = {
      script = ''
        printf 'before\n' > before; printf 'after\n' > after
        status=0
        ${package}/bin/diff --old-line-format='-%L' --new-line-format='+%L' before after || status=$?
        test "$status" = 1
        ${package}/bin/cmp before before
      '';
      expected = "-before\n+after";
    };
    pagination = {
      script = ''
        printf 'before\n' > before
        printf 'after\n' > after
        status=0
        ${package}/bin/diff -l before after > paginated || status=$?
        test "$status" = 1
        grep '^< before$' paginated
      '';
      expected = "< before";
    };
    pagination-helper = {
      script = ''
        mkdir helpers
        printf '#!${pkgs.runtimeShell}\nexit 99\n' > helpers/pr
        chmod +x helpers/pr
        export PATH="$PWD/helpers:$PATH"
        # configure must retain the declared pr even when PATH offers another.
        grep -aFq '${package.tvp.deps.coreutils}/bin/pr' ${package}/bin/diff
        printf 'before\n' > before
        printf 'after\n' > after
        for mode in -l -ly; do
          status=0
          ${package}/bin/diff "$mode" before after > paginated || status=$?
          test "$status" = 1
          grep -q before paginated
          grep -q after paginated
        done
        echo owned-pr
      '';
      expected = "owned-pr";
    };
    helpers = {
      script = ''
        mkdir helpers
        cat > helpers/diff <<'EOF'
        #!${pkgs.runtimeShell}
        echo called >> "$DIFF_HELPER_LOG"
        exec ${package}/bin/diff "$@"
        EOF
        chmod +x helpers/diff
        export PATH="$PWD/helpers:$PATH"
        export DIFF_HELPER_LOG="$PWD/helper.log"
        printf 'same\n' > first
        cp first second
        cp first third
        # Upstream intentionally resolves the default diff through PATH.
        ${package}/bin/diff3 first second third > three
        test ! -s three
        test -s helper.log
        rm helper.log
        ${package}/bin/sdiff first second > side
        test -s side
        test -s helper.log
        rm helper.log
        # An explicit helper bypasses PATH selection.
        ${package}/bin/diff3 --diff-program=${package}/bin/diff first second third > three
        ${package}/bin/sdiff --diff-program=${package}/bin/diff first second > side
        test ! -e helper.log
        echo diff-helpers
      '';
      expected = "diff-helpers";
    };
  };
}

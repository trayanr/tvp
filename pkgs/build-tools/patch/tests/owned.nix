{
  pkgs,
  tvp,
  tvpLib,
  package,
}:
let
  steps = tvp.builder.steps;
  edited = (package.override { doCheck = false; }).editSteps (
    steps.insertAfter "patch.install" [
      {
        name = "probe.installed";
        run = ''
          test -x "$out/bin/patch"
          printf 'ordered-install-edit\n' > "$out/owned-edit"
        '';
      }
    ]
  );
in
tvpLib.tests.mkSuite {
  inherit pkgs package;
  tests = {
    reverse-and-dry-run = {
      script = ''
        printf 'before\n' > sample
        printf '%s\n' '--- sample' '+++ sample' '@@ -1 +1 @@' '-before' '+after' > changes
        ${package}/bin/patch -s --dry-run -p0 < changes
        test "$(cat sample)" = before
        ${package}/bin/patch -s -p0 < changes
        test "$(cat sample)" = after
        ${package}/bin/patch -s -R -p0 < changes
        cat sample
      '';
      expected = "before";
    };
    reject-and-backup = {
      script = ''
        printf 'before\n' > sample
        printf '%s\n' '--- sample' '+++ sample' '@@ -1 +1 @@' '-before' '+after' > changes
        ${package}/bin/patch -s --backup -p0 < changes
        test "$(cat sample.orig)" = before
        if ${package}/bin/patch -s --forward -p0 < changes >&2; then exit 1; fi
        test -s sample.rej
        test "$(cat sample)" = after
        echo ok
      '';
      expected = "ok";
    };
    named-edit = {
      extraInputs = [ edited ];
      script =
        assert edited.tests.operation.drvPath != package.tests.operation.drvPath;
        ''
          ${edited}/bin/patch --version >&2
          cat ${edited}/owned-edit
        '';
      expected = "ordered-install-edit";
    };
  };
}
